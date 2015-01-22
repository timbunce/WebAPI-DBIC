package WebAPI::DBIC::Resource::ActiveModel::Role::DBIC;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::DBIC - a role with core methods for DBIx::Class resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'get_url_for_item_relationship';
requires 'render_item_as_plain_hash';
requires 'path_for_item';
requires 'add_params_to_url';
requires 'prefetch';
requires 'type_namer';



sub activemodel_type {
    my ($self) = @_;
    return $self->type_namer->type_name_for_resultset($self->set);
}


sub render_activemodel_prefetch_rel {
    my ($self, $set, $relname, $sub_rel, $top_links, $compound_links, $item_edit_rel_hooks) = @_;

    my $rel_info = $set->result_class->relationship_info($relname);
    my $result_class = $rel_info->{class}||die "panic";

    my @idcolumns = $result_class->unique_constraint_columns('primary'); # XXX wrong
    if (@idcolumns > 1) { # eg many-to-many that doesn't have a separate id
        warn "Result class $result_class has multiple keys (@idcolumns) so relations like $relname won't have links generated.\n"
            unless our $warn_once->{"$result_class $relname"}++;
        return;
    }

    my $link_url_templated = $self->get_url_template_for_set_relationship($self->set, $relname);
    return if not defined $link_url_templated;

    # TODO: This is not a type_name, need to decide what to call it and treat it differently
    my $rel_typename = $self->type_namer->type_name_for_result_class($rel_info->{class});

    die "panic: item_edit_rel_hooks for $relname already defined"
        if $item_edit_rel_hooks->{$relname};
    $item_edit_rel_hooks->{$relname} = sub {
        my ($activemodel_obj, $row) = @_;

        my $subitem = $row->$relname();

        my $compound_links_for_rel = $compound_links->{$rel_typename} ||= {};

        my $link_keys;
        if (not defined $subitem) {
            $link_keys = undef;
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            $link_keys = [];
            while (my $subrow = $subitem->next) {
                my $id = $subrow->id;
                push @$link_keys, $id;
                $compound_links_for_rel->{$id} = $self->render_item_as_activemodel_hash($subrow); # XXX typename
            }
        }
        elsif ($subitem->isa('DBIx::Class::Row')) { # one-to-many rel
            $link_keys = $subitem->id;
            $compound_links_for_rel->{$subitem->id} = $self->render_item_as_activemodel_hash($subitem); # XXX typename
        }
        else {
            die "panic: don't know how to handle $row $relname value $subitem";
        }

        $activemodel_obj->{$rel_typename} = $link_keys;
    }
}


sub render_activemodel_response { # return top-level document hashref
    my ($self) = @_;

    my $set = $self->set;

    my $top_links = {};
    my $compound_links = {};
    my $item_edit_rel_hooks = {};

    for my $prefetch (@{$self->prefetch||[]}) {
        #warn "prefetch $prefetch";
        next if $self->param('distinct');

        while (my ($relname, $sub_rel) = each %{$prefetch}){
            #warn "prefetch $prefetch - $relname, $sub_rel";
            $self->render_activemodel_prefetch_rel($set, $relname, $sub_rel, $top_links, $compound_links, $item_edit_rel_hooks);
        }
    }

    my $set_data = $self->render_set_as_array_of_activemodel_resource_objects($set, undef, sub {
        my ($activemodel_obj, $row) = @_;
        $_->($activemodel_obj, $row) for values %$item_edit_rel_hooks;
    });

    # construct top document to return
    my $top_set_key = ($self->param('distinct')) ? 'data' : $self->activemodel_type;
    my $top_doc = { # http://jsonapi.org/format/#document-structure-top-level
        $top_set_key => $set_data,
    };

    if (keys %$top_links) {
#        $top_doc->{links} = $top_links
    }

    if (keys %$compound_links) {
        #Dwarn $compound_links;
        while ( my ($k, $v) = each %$compound_links) {
            # sort just for test stability,
#            $top_doc->{linked}{$k} = [ @{$v}{ sort keys %$v } ];
        }
    }

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $top_doc->{meta}{count} = $total_items; # XXX detail not in spec
    }

    return $top_doc;
}



sub render_item_as_activemodel_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

#    $data->{id} //= $item->id;
#    $data->{type} = $self->type_namer->type_name_for_result_class($item->result_source->result_class);
#    $data->{href} = $self->path_for_item($item);

    #$self->_render_prefetch_activemodel($item, $data, $_) for @{$self->prefetch||[]};

    # add links for relationships

    return $data;
}


sub _render_prefetch_activemodel {
    my ($self, $item, $data, $prefetch) = @_;

    while (my ($rel, $sub_rel) = each %{$prefetch}){
        next if $rel eq 'self';

        my $subitem = $item->$rel();

        if (not defined $subitem) {
            $data->{_embedded}{$rel} = undef; # show an explicit null from a prefetch
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            my $rel_set_resource = $self->web_machine_resource(
                set         => $subitem,
                item        => undef,
                prefetch    => ref $sub_rel eq 'ARRAY' ? $sub_rel : [$sub_rel],
            );
            $data->{_embedded}{$rel} = $rel_set_resource->render_set_as_array_of_activemodel_resource_objects($subitem, undef);
        }
        else {
            $data->{_embedded}{$rel} = $self->render_item_as_plain_hash($subitem);
        }
    }
}

sub render_set_as_array_of_activemodel_resource_objects {
    my ($self, $set, $render_method, $edit_hook) = @_;
    $render_method ||= 'render_item_as_activemodel_hash';

    my @activemodel_objs;
    while (my $row = $set->next) {
        push @activemodel_objs, $self->$render_method($row);
        $edit_hook->($activemodel_objs[-1], $row) if $edit_hook;
    }

    return \@activemodel_objs;
}





1;
