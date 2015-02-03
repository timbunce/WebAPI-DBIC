package WebAPI::DBIC::Resource::JSONAPI::Role::DBIC;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::DBIC - a role with core JSON API methods for DBIx::Class resources

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



sub jsonapi_type {
    my ($self) = @_;
    return $self->type_namer->type_name_for_resultset($self->set);
}


sub top_link_for_relname { # XXX cacheable
    my ($self, $relname) = @_;

    my $link_url_templated = $self->get_url_template_for_set_relationship($self->set, $relname);
    return if not defined $link_url_templated;

    # XXX a hack to keep the template urls readable!
    $link_url_templated =~ s/%7B/{/g;
    $link_url_templated =~ s/%7D/}/g;

    my $rel_info = $self->set->result_class->relationship_info($relname);
    my $result_class = $rel_info->{class}||die "panic";

    my $rel_jsonapi_type = $self->type_namer->type_name_for_result_class($result_class);

    my $path = $self->jsonapi_type .".". $relname;
    return $path => {
        href => "$link_url_templated", # XXX stringify the URL object
        type => $rel_jsonapi_type,
    };
}


sub render_jsonapi_prefetch_rel {
    my ($self, $set, $relname, $sub_rel, $top_links, $compound_links, $item_edit_rel_hooks) = @_;

    my $rel_info = $set->result_class->relationship_info($relname);
    my $result_class = $rel_info->{class}||die "panic";

    my @idcolumns = $result_class->unique_constraint_columns('primary'); # XXX wrong
    if (@idcolumns > 1) { # eg many-to-many that doesn't have a separate id
        warn "Result class $result_class has multiple keys (@idcolumns) so relations like $relname won't have links generated.\n"
            unless our $warn_once->{"$result_class $relname"}++;
        return;
    }

    my ($top_link_key, $top_link_value) = $self->top_link_for_relname($relname)
        or return;
    $top_links->{$top_link_key} = $top_link_value;

    my $rel_typename = $self->type_namer->type_name_for_result_class($rel_info->{class});

    die "panic: item_edit_rel_hooks for $relname already defined"
        if $item_edit_rel_hooks->{$relname};
    $item_edit_rel_hooks->{$relname} = sub {
        my ($jsonapi_obj, $row) = @_;

        # Prevent joins calling the DB for no cached
        # relations in the join statement
        if ($self->param('join')){
            return unless
                defined $row->{related_resultsets}{$relname} &&
                defined $row->{related_resultsets}{$relname}->get_cache;
        }

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
                $compound_links_for_rel->{$id} = $self->render_item_as_jsonapi_hash($subrow); # XXX typename
            }
        }
        elsif ($subitem->isa('DBIx::Class::Row')) { # one-to-many rel
            $link_keys = $subitem->id;
            $compound_links_for_rel->{$subitem->id} = $self->render_item_as_jsonapi_hash($subitem); # XXX typename
        }
        else {
            die "panic: don't know how to handle $row $relname value $subitem";
        }

        $jsonapi_obj->{links}{$rel_typename} = $link_keys;
    }
}


sub render_jsonapi_response { # return top-level document hashref
    my ($self) = @_;

    my $set = $self->set;

    my $top_links = {};
    my $compound_links = {};
    my $item_edit_rel_hooks = {};

    for my $prefetch (@{$self->prefetch||[]}) {
        #warn "prefetch $prefetch";
        next if $self->param('distinct');

        while (my ($relname, $sub_rel) = each %{$prefetch}){
            $self->render_jsonapi_prefetch_rel($set, $relname, $sub_rel, $top_links, $compound_links, $item_edit_rel_hooks);
        }
    }

    my $set_data = $self->render_set_as_array_of_jsonapi_resource_objects($set, undef, sub {
        my ($jsonapi_obj, $row) = @_;
        $_->($jsonapi_obj, $row) for values %$item_edit_rel_hooks;
    });

    # construct top document to return
    my $top_set_key = ($self->param('distinct')) ? 'data' : $self->jsonapi_type;
    my $top_doc = { # http://jsonapi.org/format/#document-structure-top-level
        $top_set_key => $set_data,
    };

    if (keys %$top_links) {
        $top_doc->{links} = $top_links
    }

    if (keys %$compound_links) {
        #Dwarn $compound_links;
        while ( my ($k, $v) = each %$compound_links) {
            # sort just for test stability,
            $top_doc->{linked}{$k} = [ @{$v}{ sort keys %$v } ];
        }
    }

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $top_doc->{meta}{count} = $total_items; # XXX detail not in spec
    }

    return $top_doc;
}



sub render_item_as_jsonapi_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    $data->{id} //= $item->id;
    $data->{type} = $self->type_namer->type_name_for_result_class($item->result_source->result_class);
    $data->{href} = $self->path_for_item($item);

    #$self->_render_prefetch_jsonapi($item, $data, $_) for @{$self->prefetch||[]};

    # add links for relationships

    return $data;
}


sub _render_prefetch_jsonapi {
    my ($self, $item, $data, $prefetch) = @_;

    while (my ($rel, $sub_rel) = each %{$prefetch}){
        next if $rel eq 'self';

        # Prevent joins calling the DB for no cached
        # relations in the join statement
        if ($self->param('join')){
            next unless
                defined $item->{related_resultsets}{$rel} &&
                defined $item->{related_resultsets}{$rel}->get_cache;
        }
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
            $data->{_embedded}{$rel} = $rel_set_resource->render_set_as_array_of_jsonapi_resource_objects($subitem, undef);
        }
        else {
            $data->{_embedded}{$rel} = $self->render_item_as_plain_hash($subitem);
        }
    }
}

sub render_set_as_array_of_jsonapi_resource_objects {
    my ($self, $set, $render_method, $edit_hook) = @_;
    $render_method ||= 'render_item_as_jsonapi_hash';

    my @jsonapi_objs;
    while (my $row = $set->next) {
        push @jsonapi_objs, $self->$render_method($row);
        $edit_hook->($jsonapi_objs[-1], $row) if $edit_hook;
    }

    return \@jsonapi_objs;
}




sub _jsonapi_page_links {
    my ($self, $set, $base, $page_items, $total_items) = @_;

    # XXX we ought to allow at least the self link when not pages
    return () unless $set->is_paged;

    # XXX we break encapsulation here, sadly, because calling
    # $set->pager->current_page triggers a "select count(*)".
    # XXX When we're using a later version of DBIx::Class we can use this:
    # https://metacpan.org/source/RIBASUSHI/DBIx-Class-0.08208/lib/DBIx/Class/ResultSet/Pager.pm
    # and do something like $rs->pager->total_entries(sub { 99999999 })
    my $rows = $set->{attrs}{rows} or confess "panic: rows not set";
    my $page = $set->{attrs}{page} or confess "panic: page not set";

    # XXX this self link this should probably be subtractive, ie include all
    # params by default except any known to cause problems
    my $url = $self->add_params_to_url($base, { distinct=>1, with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => {
        href => $linkurl.($page),
        title => $set->result_class,
    };
    push @link_kvs, next  => { href => $linkurl.($page+1) }
        if $page_items == $rows;
    push @link_kvs, prev  => { href => $linkurl.($page-1) }
        if $page > 1;
    push @link_kvs, first => { href => $linkurl.1 }
        if $page > 1;
    push @link_kvs, last  => { href => $linkurl.$set->pager->last_page }
        if $total_items and $page != $set->pager->last_page;

    return @link_kvs;
}


1;
