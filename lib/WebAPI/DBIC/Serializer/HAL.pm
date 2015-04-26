package WebAPI::DBIC::Serializer::HAL;

=head1 NAME

WebAPI::DBIC::Serializer::HAL

=cut

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';


use Carp qw(croak confess);
use Try::Tiny;
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);


sub content_types_accepted {
    return ( [ 'application/hal+json' => 'accept_from_json' ]);
}

sub content_types_provided {
    return ( [ 'application/hal+json' => 'provide_to_json' ]);
}

sub set_to_json   {
    my $self = shift;
    my $set = shift || $self->resource->set;

    return $self->encode_json($self->render_set_as_data($set));
}


sub item_to_json {
    my $self = shift;
    my $item = shift || $self->resource->item;

    return $self->resource->encode_json($self->render_item_as_data($item))
}


sub item_from_json {
    my $self = shift;
    my $data = $self->decode_json( shift || $self->resource->request->content );

    $self->update_resource($data, is_put_replace => 0);

    return;
}


sub set_from_json {
    my $self = shift;
    my $data = $self->decode_json( shift || $self->resource->request->content );

    my $item = $self->create_resources_from_data( $data );

    return $self->resource->item($item);
}


sub render_item_as_data {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    my $itemurl = $self->path_for_item($item);
    $data->{_links}{self} = {
        href => $self->add_params_to_url($itemurl, {}, {})->as_string,
    };

    $self->_render_prefetch($item, $data, $_) for @{$self->prefetch||[]};

    my $curie = (0) ? "r" : ""; # XXX we don't use CURIE syntax yet

    # add links for relationships
    for my $relname ($item->result_class->relationships) {

        my $url = $self->get_url_for_item_relationship($item, $relname)
            or next;

        $data->{_links}{ ($curie?"$curie:":"") . $relname} = { href => $url->as_string };
    }
    if ($curie) {
       $data->{_links}{curies} = [{
         name => $curie,
         href => "http://docs.acme.com/relations/{rel}", # XXX
         templated => JSON->true,
       }];
   }

    return $data;
}


sub _render_prefetch {
    my ($self, $item, $data, $prefetch) = @_;

    while (my ($rel, $sub_rel) = each %{$prefetch}){
        next if $rel eq 'self';

        my $subitem = $item->$rel();

        # XXX perhaps render_item_as_data but requires cloned WM, eg without prefetch
        # If we ever do render_item_as_data then we need to ensure that "a link
        # inside an embedded resource implicitly relates to that embedded
        # resource and not the parent."
        # See http://blog.stateless.co/post/13296666138/json-linking-with-hal
        if (not defined $subitem) {
            $data->{_embedded}{$rel} = undef; # show an explicit null from a prefetch
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            my $rel_set_resource = $self->web_machine_resource(
                set         => $subitem,
                prefetch    => ref $sub_rel eq 'ARRAY' ? $sub_rel : [$sub_rel],
            );
            $data->{_embedded}{$rel} = $rel_set_resource->serializer->render_set_as_list_of_hal($subitem);
        }
        else {
            $data->{_embedded}{$rel} = $self->render_item_as_plain_hash($subitem);
        }
    }
}


sub render_set_as_list_of_hal {
    my ($self, $set, $render_method) = @_;
    $render_method ||= 'render_item_as_data';

    my $set_data = [ map { $self->$render_method($_) } $set->all ];

    return $set_data;
}


sub render_set_as_data {
    my ($self, $set) = @_;

    # some params, like distinct, mean we're not returning full resource representations(?)
    # so render the contents of the _embedded set as plain JSON
    my $render_method = ($self->param('distinct'))
        ? 'render_item_as_plain_hash'
        : 'render_item_as_data';
    my $set_data = $self->render_set_as_list_of_hal($set, $render_method);

    my $data = {};

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $data->{_meta}{count} = $total_items;
    }

    my ($prefix, $rel) = $self->uri_for(result_class => $set->result_class);
    $data->{_embedded} = {
        $rel => $set_data,
    };
    $data->{_links} = {
        $self->_hal_page_links($set, "$prefix/$rel", scalar @$set_data, $total_items),
    };

    return $data;
}


sub _hal_page_links {
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


# recurse to create resources in $hal->{_embedded}
#   and update coresponding attributes in $hal
# then create $hal itself
sub _create_embedded_resources_from_data {
    my ($self, $hal, $result_class) = @_;

    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation\n";
        die "$result_class _embedded $rel isn't a 'single' relationship\n"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_hal = $embedded->{$rel};
        die "_embedded $rel data is not a hash\n"
            if ref $rel_hal ne 'HASH';

        # work out what keys to copy from the subitem we're about to create
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//x    or confess "panic $rel $our_field";
            $sub_field =~ s/^foreign\.//x or confess "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$result_class already contains a value for '$our_field'\n"
                if defined $hal->{$our_field}; # null is ok
        }

        # create this subitem (and any resources embedded in it)
        my $subitem = $self->_create_embedded_resources_from_data($rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to create
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }
    }

    return $self->set->result_source->schema->resultset($result_class)->create($hal);
}


# ===

sub pre_update_resource_method {
    my ($self, $item, $hal, $result_class) = @_;

    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation\n";
        die "$result_class _embedded $rel isn't a 'single' relationship\n"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_hal = $embedded->{$rel};
        die "_embedded $rel data is not a hash\n"
            if ref $rel_hal ne 'HASH';

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
                if defined $hal->{$our_field}; # null is ok
        }

        # update this subitem (and any resources embedded in it)
        my $subitem = $item->$rel();
        $subitem = $self->_do_update_resource($subitem, $rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to update
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }

        # XXX perhaps save $subitem to optimise prefetch handling?
    }

    return;
}


1;
