package WebAPI::DBIC::Resource::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::Role::ItemWritable - methods handling requests to update item resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;

use Moo::Role;


requires 'render_item_into_body';
requires 'decode_json';
requires 'item';
requires 'param';
requires 'prefetch';
requires 'request';
requires 'response';
requires 'path_for_item';


# By default the DBIx::Class::Row update() call will only update the
# columns where %$hal contains different values to the ones in $item.
# This is usually a useful optimization but not always. So we provide
# a way to disable it on individual resources.
has skip_dirty_check => (
    is => 'rw',
);

has _pre_update_resource_method => (
    is => 'rw',
);

has content_types_accepted => (
    is => 'lazy',
);

sub _build_content_types_accepted {
    return [ {'application/json' => 'from_plain_json'} ]
}


sub from_plain_json {
    my $self = shift;
    my $data = $self->decode_json( $self->request->content );
    $self->update_resource($data, is_put_replace => 0);
    return;
}


around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;
 
    my $methods = $self->$orig();

    $methods = [ qw(PUT DELETE), @$methods ] if $self->writable;

    return $methods;
};


sub delete_resource { return $_[0]->item->delete }


sub _do_update_resource {
    my ($self, $item, $hal, $result_class) = @_;

    # provide a hook for richer behaviour, eg HAL
    my $_pre_update_resource_method = $self->_pre_update_resource_method;
    $self->$_pre_update_resource_method($item, $hal, $result_class)
        if $_pre_update_resource_method;

    # By default the DBIx::Class::Row update() call below will only update the
    # columns where %$hal contains different values to the ones in $item
    # This is usually a useful optimization but not always. So we provide
    # a way to disable it on individual resources.
    if ($self->skip_dirty_check) {
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

    my $schema = $self->item->result_source->schema;
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

            my $old_item = $self->item; # XXX might already be gone since the find()
            $old_item->delete if $old_item; # XXX might already be gone since the find()

            my $links    = delete $hal->{_links};
            my $meta     = delete $hal->{_meta};
            my $embedded = delete $hal->{_embedded} && die "_embedded not supported here (yet?)\n";

            $item = $self->set->create($hal); # handles deflation

            $self->response->header('Location' => $self->path_for_item($item))
                unless $old_item; # set Location and thus 201 if Created not modified
        }
        else {
            $item = $self->_do_update_resource($self->item, $hal, $self->item->result_class);
        }

        $self->item($item);

        # called here because create_path() is too late for WM
        # and we need it to happen inside the transaction for rollback=1 to work
        # XXX requires 'self' prefetch to get any others
        $self->render_item_into_body() if grep {defined $_->{self}} @{$self->prefetch//[]};

        $schema->txn_rollback if $self->param('rollback'); # XXX
    });
    return;
}

1;
