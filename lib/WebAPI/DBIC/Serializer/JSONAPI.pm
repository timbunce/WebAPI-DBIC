package WebAPI::DBIC::Serializer::JSONAPI;

=head1 NAME

WebAPI::DBIC::Serializer::JSONAPI - what will I become?

=cut

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';


use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);


sub set_to_json {
    my $self = shift;
    my $set = shift;

    return $self->encode_json( $self->render_jsonapi_response($set) );
}


sub item_to_json {
    my $self = shift;
    my $item = shift;

    # narrow the set to just contain the specified item
    # XXX this narrowing ought to be moved elsewhere
    # seems like a bad idea to be a side effect of this method
    my @id_cols = $self->set->result_source->unique_constraint_columns( $self->resource->id_unique_constraint_name );
    @id_cols = map { $self->set->current_source_alias.".$_" } @id_cols;
    my %id_search; @id_search{ @id_cols } = @{ $self->resource->id };
    $self->set( $self->set->search_rs(\%id_search) ); # narrow the set

    # set has been narrowed to the item, so we can render the item as if a set
    # (which is what we need to do for JSON API, which doesn't really have an 'item')

    return $self->encode_json( $self->render_jsonapi_response($self->set) );
}


sub item_from_json {
    my $self = shift;
    my $data = $self->decode_json( shift );

    $self->update_resource($data, is_put_replace => 0);

    return;
}


sub set_from_json {
    my $self = shift;
    my $data = $self->decode_json( shift );

    my $item = $self->create_resource( $data );

    return $self->item($item);
}


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
    my ($self, $set) = @_;

    my $top_links = {};
    my $compound_links = {};
    my $item_edit_rel_hooks = {};

    for my $prefetch (@{$self->prefetch||[]}) {
        #warn "prefetch $prefetch";
        next if $self->param('distinct');

        while (my ($relname, $sub_rel) = each %{$prefetch}){
            #warn "prefetch $prefetch - $relname, $sub_rel";
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


# === Methods for Writable resources


sub create_resource { # XXX unify with create_resource in SetWritable, like ItemWritable?
    my ($self, $jsonapi) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources_from_jsonapi($jsonapi, $self->set->result_class);

        # resync with what's (now) in the db to pick up defaulted fields etc
        $item->discard_changes();

        # called here because create_path() is too late for Web::Machine
        # and we need it to happen inside the transaction for rollback=1 to work
        $self->render_item_into_body(item => $item, prefetch => $self->prefetch)
            if grep {defined $_->{self}} @{$self->prefetch||[]};

        $schema->txn_rollback if $self->param('rollback'); # XXX
    });

    return $item;
}


# recurse to create resources in $jsonapi->{_embedded}
#   and update coresponding attributes in $jsonapi
# then create $jsonapi itself
sub _create_embedded_resources_from_jsonapi {
    my ($self, $jsonapi, $result_class) = @_;

    my $links    = delete $jsonapi->{_links};
    my $meta     = delete $jsonapi->{_meta};
    my $embedded = delete $jsonapi->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation\n";
        die "$result_class _embedded $rel isn't a 'single' relationship\n"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_jsonapi = $embedded->{$rel};
        die "_embedded $rel data is not a hash\n"
            if ref $rel_jsonapi ne 'HASH';

        # work out what keys to copy from the subitem we're about to create
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//x    or confess "panic $rel $our_field";
            $sub_field =~ s/^foreign\.//x or confess "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$result_class already contains a value for '$our_field'\n"
                if defined $jsonapi->{$our_field}; # null is ok
        }

        # create this subitem (and any resources embedded in it)
        my $subitem = $self->_create_embedded_resources_from_jsonapi($rel_jsonapi, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to create
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $jsonapi->{$ourfield} = $subitem->$subfield();
        }
    }

    return $self->set->result_source->schema->resultset($result_class)->create($jsonapi);
}


sub pre_update_resource_method {
    my ($self, $item, $jsonapi, $result_class) = @_;

    my $links    = delete $jsonapi->{_links};
    my $meta     = delete $jsonapi->{_meta};
    my $embedded = delete $jsonapi->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation\n";
        die "$result_class _embedded $rel isn't a 'single' relationship\n"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_jsonapi = $embedded->{$rel};
        die "_embedded $rel data is not a hash\n"
            if ref $rel_jsonapi ne 'HASH';

        # work out what keys to copy from the subitem we're about to update
        # XXX this isn't required unless updating key fields - optimize
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//x    or confess "panic $rel $our_field";
            $sub_field =~ s/^foreign\.//x or confess "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$result_class already contains a value for '$our_field'\n"
                if defined $jsonapi->{$our_field}; # null is ok
        }

        # update this subitem (and any resources embedded in it)
        my $subitem = $item->$rel();
        $subitem = $self->resource->_do_update_resource($subitem, $rel_jsonapi, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to update
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $jsonapi->{$ourfield} = $subitem->$subfield();
        }

        # XXX perhaps save $subitem to optimise prefetch handling?
    }

    return;
}

1;
