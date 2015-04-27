package WebAPI::DBIC::Serializer::Base;

=head1 NAME

WebAPI::DBIC::Serializer::Base - what will I become?

=cut

use Moo;

use Carp;
use Scalar::Util qw(blessed);


has resource => (
    is => 'ro',
    required => 1,
    weak_ref => 1,
    # XXX these are here for now to ease migration to use of a serializer object
    # they also serve to identify areas that probably need refactoring/abstracting
    handles => [qw(
        set

        type_namer
        get_url_template_for_set_relationship
        get_url_for_item_relationship
        uri_for
        prefetch
        param
        add_params_to_url
        path_for_item
        web_machine_resource
    )],
);


sub set_to_json   {
    my $self = shift;
    my $set = shift;
    return $self->encode_json($self->render_set_as_plain($set));
}

sub item_to_json {
    my $self = shift;
    my $item = shift;
    return $self->resource->encode_json($self->render_item_as_plain_hash($item))
}


sub set_from_json { # insert into set
    my $self = shift;
    my $data = $self->decode_json( shift );

    my $item = $self->create_resources_from_data( $data );
    return $self->resource->item($item);
}

sub item_from_json { # update
    my $self = shift;
    my $data = $self->decode_json( shift );

    $self->update_resource($data, is_put_replace => 0);

    return;
}


# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    Carp::confess("bad item: $item") unless blessed $item;
    my $data = { $item->get_columns }; # XXX ?
    # XXX inflation, DateTimes, etc.
    return $data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain_hash($_) } $set->all ];
    return $set_data;
}


sub create_should_prefetch_self {
    my $self = shift;
    return scalar grep {defined $_->{self}} @{$self->prefetch||[]};
}


sub create_resources_from_data {
    my ($self, $data) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;

    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources_from_data($data, $self->set->result_class);

        # resync with what's (now) in the db to pick up defaulted fields etc
        $item->discard_changes();

        # called here because create_path() is too late for Web::Machine
        # and we need it to happen inside the transaction for rollback=1 to work
        $self->resource->render_item_into_body(
                set => $self->set,
                item => $item,
                type_namer => $self->type_namer,
                prefetch => $self->prefetch,
            )
            if $self->create_should_prefetch_self;

        $schema->txn_rollback if $self->param('rollback'); # XXX

    });

    return $item;
}


# recurse into a prefetch-like structure invoking a callback
# XXX still a work in progress, only used by ActiveModule so far
sub traverse_prefetch {
    my $self = shift;
    my $set = shift;
    my $parent_rel = shift;
    my $prefetch = shift;
    my $callback = shift;

    return unless $prefetch;

    if (not ref($prefetch)) { # leaf node
        $callback->($self, $set, $parent_rel, $prefetch);
        return;
    }

    if (ref($prefetch) eq 'HASH') {
        while (my ($prefetch_key, $prefetch_value) = each(%$prefetch)) {
            warn "traverse_prefetch [@$parent_rel] $prefetch\{$prefetch_key}\n"
                if $ENV{WEBAPI_DBIC_DEBUG};
            next if $prefetch_key eq 'self';

            $self->traverse_prefetch($set, $parent_rel,   $prefetch_key, $callback);

            # XXX traverse_prefetch first arg is a set but this passes a class:
            my $result_subclass = $set->result_class->relationship_info($prefetch_key)->{class};

            $self->traverse_prefetch($result_subclass, [ @$parent_rel, $prefetch_key ], $prefetch_value, $callback);
        }
    }
    elsif (ref($prefetch) eq 'ARRAY') {
        for my $sub_prefetch (@$prefetch) {
            $self->traverse_prefetch($set, $parent_rel, $sub_prefetch, $callback);
        }
    }
    else {
        confess "Unsupported ref(prefetch): " . ref($prefetch);
    }

    return;
}


# ====== Item Writable ======

sub _do_update_resource {
    my ($self, $item, $hal, $result_class) = @_;

    # hook for richer behaviour, eg HAL
    if (my $_pre_update_resource_method = $self->resource->_pre_update_resource_method) {
        $self->resource->$_pre_update_resource_method($item, $hal, $result_class);
    }
    elsif (1) {
        $self->pre_update_resource_method($item, $hal, $result_class) # XXX wip
            if $self->can('pre_update_resource_method');
    }

    # By default the DBIx::Class::Row update() call below will only update the
    # columns where %$hal contains different values to the ones in $item
    # This is usually a useful optimization but not always. So we provide
    # a way to disable it on individual resources.
    if ($self->resource->skip_dirty_check) {
        $item->make_column_dirty($_) for keys %$hal;
    }

    # Note that update() calls set_inflated_columns()
    $item->update($hal);

    # XXX discard_changes causes a refetch of the record for prefetch
    # perhaps worth trying to avoid the discard if not required
    $item->discard_changes();

    return $item;
}


sub update_resource {
    my ($self, $hal, %opts) = @_;
    my $is_put_replace = delete $opts{is_put_replace};
    croak "update_resource: invalid options: @{[ keys %opts ]}"
        if %opts;

    my $schema = $self->resource->item->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        my $item;
        if ($is_put_replace) {
            # PUT == http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.6

            # Using delete() followed by create() is a strict implementation
            # of treating PUT on an item as a REPLACE, but it might not be ideal.
            # Specifically it requires any FKs to be DEFERRED and it'll less
            # efficient than a simple UPDATE. There's also a concern that if
            # the REST API only has a partial view of the resource, ie not all
            # columns, then do we want the original deleted if the 'hidden'
            # fields can't be set?
            # So this could me made optional on a per-resource-class basis,
            # and/or via a request parameter.

            # we require PK fields to at least be defined
            # XXX we ought to check that they match the URL since a PUT is
            # required to store the entity "under the supplied Request-URI".
            # XXX throw proper exception
            defined $hal->{$_} or die "missing PK '$_'\n"
                for $self->set->result_source->primary_columns;

            my $old_item = $self->resource->item; # XXX might already be gone since the find()
            $old_item->delete if $old_item; # XXX might already be gone since the find()

            my $links    = delete $hal->{_links};
            my $meta     = delete $hal->{_meta};
            my $embedded = delete $hal->{_embedded} && die "_embedded not supported here (yet?)\n";

            $item = $self->set->create($hal); # handles deflation

            $self->response->header('Location' => $self->path_for_item($item))
                unless $old_item; # set Location and thus 201 if Created not modified
        }
        else {
            $item = $self->_do_update_resource($self->resource->item, $hal, $self->resource->item->result_class);
        }

        $self->resource->item($item);

        # called here because create_path() is too late for WM
        # and we need it to happen inside the transaction for rollback=1 to work
        # XXX requires 'self' prefetch to get any others
        $self->resource->render_item_into_body() if grep {defined $_->{self}} @{$self->prefetch||[]};

        $schema->txn_rollback if $self->param('rollback'); # XXX
    });
    return;
}


# ====== Set Writable ======

sub create_resource {
    my ($self, $data) = @_;

    my $item = $self->set->create($data);

    # resync with what's (now) in the db to pick up defaulted fields etc
    $item->discard_changes();

    # called here because create_path() is too late for Web::Machine
    $self->render_item_into_body(item => $item)
        if grep {defined $_->{self}} @{$self->prefetch||[]};

    return $item;
}


1;
