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


sub traverse_prefetch {
    my $self = shift;
    my $set = shift;
    my $parent_rel = shift;
    my $prefetch = shift;
    my $rel_fcn = shift;
    my @rel_fcn_args = @_;

    return unless($prefetch);

    if($prefetch && !ref($prefetch)) {
        $self->$rel_fcn($set, $parent_rel, $prefetch, @rel_fcn_args);
    }
    elsif(ref($prefetch) eq 'HASH') {
        while(my ($prefetch_key, $prefetch_value) = each(%{$prefetch})) {
            $self->traverse_prefetch($set, $parent_rel, $prefetch_key, $rel_fcn, @rel_fcn_args);
            my $result_subclass = $set->result_class->relationship_info($prefetch_key)->{class};
            $self->traverse_prefetch($result_subclass, $prefetch_key, $prefetch_value, $rel_fcn, @rel_fcn_args);
        }
    }
    elsif(ref($prefetch) eq 'ARRAY') {
        for my $sub_prefetch(@{$prefetch}) {
            $self->traverse_prefetch($set, $parent_rel, $sub_prefetch, $rel_fcn, @rel_fcn_args);
        }
    }
    else {
        warn "Unsupported ref(prefetch): " . ref($prefetch);
    }
}


sub render_activemodel_prefetch_rel {
    my ($self, $set, $parent_relname, $relname, $top_links, $rel_sets, $item_edit_rel_hooks) = @_;

    my $parent_class = $set->result_class;
    my $child_class = $parent_class->relationship_info($relname)->{class} || die "panic";

    my @idcolumns = $child_class->unique_constraint_columns('primary'); # XXX wrong
    if (@idcolumns > 1) { # eg many-to-many that doesn't have a separate id
        warn "Child result class $child_class has multiple keys (@idcolumns) so relations like $relname won't have links generated.\n"
            unless our $warn_once->{"$child_class $relname"}++;
        return;
    }

    my $rel_typename = $self->type_namer->type_name_for_result_class($child_class);

    return if $item_edit_rel_hooks->{$parent_relname}->{$relname};

    $item_edit_rel_hooks->{$parent_relname}->{$relname} = sub {
        my ($activemodel_obj, $row) = @_;

        my $subitem = $row->$relname();

        my $rel_set = $rel_sets->{$rel_typename} ||= {};

        my $rel_ids;
        if (not defined $subitem) {
            $rel_ids = undef;
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            $rel_ids = [];
            while (my $subrow = $subitem->next) {
                my $id = $subrow->id;
                push @$rel_ids, $id;
                my $rel_object = $self->render_row_as_activemodel_resource_object($subrow, undef, sub {
                    my ($activemodel_obj, $row) = @_;
                    $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{$relname}};
                });
                # In case this object has been pulled in before, do what we can
                # to preserve the existing keys and add to them as appropriate.
                $rel_set->{$id} //= {};
                $rel_set->{$id} = { %{$rel_object}, %{$rel_set->{$id}} };
            }
        }
        elsif ($subitem->isa('DBIx::Class::Row')) { # one-to-one rel
            # $rel_ids = $subitem->id;
            my $rel_object = $self->render_row_as_activemodel_resource_object($subitem, undef, sub {
                my ($activemodel_obj, $row) = @_;
                $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{$relname}};
            });
                # In case this object has been pulled in before, do what we can
                # to preserve the existing keys and add to them as appropriate.
            $rel_set->{$subitem->id} //= {};
            $rel_set->{$subitem->id} = { %{$rel_object}, %{$rel_set->{$subitem->id}} };
        }
        else {
            die "panic: don't know how to handle $row $relname value $subitem";
        }

        # XXX We should either create a 'relationship_namer' similar to the 'type_namer',
        # or create and utilize adapter/serializer classes.
        # This should use the relationship name, singular, suffixed with '_ids'
        # This only applies to hasMany relationships since belongsTo relationships
        # will have the FK ID included in the row data itself.
        use Lingua::EN::Inflect::Number qw(to_S to_PL);
        my $relname_id = to_S($relname).'_ids';
        $activemodel_obj->{$relname_id} = $rel_ids if($rel_ids);
    }
}


sub render_activemodel_response { # return top-level document hashref
    my ($self) = @_;

    my $set = $self->set;
    my $prefetch = $self->prefetch;

    my $top_links = {};
    my $rel_sets = {};
    my $item_edit_rel_hooks = {};

    if (scalar(@{$prefetch})) {
        $self->traverse_prefetch($set, 'top', $prefetch, \&render_activemodel_prefetch_rel, $top_links, $rel_sets, $item_edit_rel_hooks)
    }
    else {
        # warn "no prefetch";
    }


    my $result_class = $set->result_class;
    my $set_data = $self->render_set_as_array_of_activemodel_resource_objects($set, undef, sub {
        my ($activemodel_obj, $row) = @_;
        $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{'top'}};
    });

    # construct top document to return
    my $top_set_key = ($self->param('distinct')) ? 'data' : $self->activemodel_type;
    my $top_doc = { # http://jsonapi.org/format/#document-structure-top-level
        $top_set_key => $set_data,
    };

    if (keys %$top_links) {
        # TODO: figure out what to do with the top_links
        # $top_doc = { %{$top_links}, %{$top_doc} };
    }

    if (keys %$rel_sets) {
        while ( my ($k, $v) = each %$rel_sets) {
            # sort just for test stability,
            $top_doc->{$k} = [ @{$v}{ sort keys %$v } ];
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

    my @activemodel_objs;
    while (my $row = $set->next) {
        push @activemodel_objs, $self->render_row_as_activemodel_resource_object($row, $render_method, $edit_hook);
    }

    return \@activemodel_objs;
}

sub render_row_as_activemodel_resource_object {
    my ($self, $row, $render_method, $edit_hook) = @_;
    $render_method ||= 'render_item_as_activemodel_hash';

    my $obj = $self->$render_method($row);
    $edit_hook->($obj, $row) if $edit_hook;

    return $obj;
}





1;
