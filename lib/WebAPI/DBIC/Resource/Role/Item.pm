package WebAPI::DBIC::Resource::Role::Item;

use Moo::Role;

use Carp;
use Devel::Dwarn;

requires 'render_item_as_plain';
requires 'render_item_as_hal';
requires 'encode_json';
requires 'decode_json';

has set => (
   is => 'ro',
   required => 0,
);

has item => (
   is => 'ro',
   required => 1,
);

has writable => (
   is => 'ro',
);

has prefetch => (
   is => 'ro',
   default => sub { { } },
);


sub content_types_accepted { [
    {'application/hal+json' => 'from_plain_json'},
    {'application/json'     => 'from_plain_json'}
] }
sub content_types_provided { [
    {'application/hal+json' => 'to_json_as_hal'},
    {'application/json'     => 'to_json_as_plain'},
] }

sub to_json_as_plain { $_[0]->encode_json($_[0]->render_item_as_plain($_[0]->item)) }
sub to_json_as_hal {   $_[0]->encode_json($_[0]->render_item_as_hal($_[0]->item)) }

sub from_plain_json { # XXX currently used for hal too
    my $self = shift;
    my $data = $self->decode_json( $self->request->content );
    $self->update_resource($data, is_put_replace => 1);
    #$self->response->body( $self->to_json_as_hal ) if $self->prefetch->{self};
}

sub resource_exists { !! $_[0]->item }

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable || 1 ) ? (qw(PUT POST DELETE)) : ()
   ]
}

sub delete_resource { $_[0]->item->delete }


sub _update_embedded_resources {
    my ($self, $item, $hal, $result_class) = @_;

    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $result_class->relationship_info($rel)
            or die "$result_class doesn't have a '$rel' relation";
        die "$result_class $rel isn't a single"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_hal = $embedded->{$rel};
        die "$rel data is not a hash"
            if ref $rel_hal ne 'HASH';

        # work out what keys to copy from the subitem we're about to update
        # XXX this isn't required unless updating key fields - optimize
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//    or die "panic $rel $our_field";
            $sub_field =~ s/^foreign\.// or die "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$result_class already contains a value for '$our_field'\n"
                if defined $hal->{$our_field}; # null is ok
        }

        # update this subitem (and any resources embedded in it)
        my $subitem = $item->$rel();
        $subitem = $self->_update_embedded_resources($subitem, $rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to update
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n";
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }

        # XXX perhaps save $subitem to optimise prefetch handling?
    }

    # XXX discard_changes causes a refetch of the record for prefetch
    # perhaps worth trying to avoid the discard if not required
    return $item->update($hal)->discard_changes();
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

            my $links    = delete $hal->{_links};
            my $meta     = delete $hal->{_meta};
            my $embedded = delete $hal->{_embedded} && die "_embedded not supported here (yet?)\n";

            # Using delete() followed by create() is a strict implementation
            # of treating PUT on an item as a REPLACE, but it might not be ideal.
            # Specifically it requires any FKs to be DEFERRED and it'll less
            # efficient than a simple UPDATE.
            # So this could me made optional on a per-resource-class basis.

            # we require PK fields to at least be defined
            # XXX we ought to check that they match the URL since a PUT is
            # required to store the entity "under the supplied Request-URI".
            # XXX throw proper exception
            defined $hal->{$_} or die "missing PK '$_'\n"
                for $self->set->result_source->primary_columns;

            my $old_item = $self->item; # XXX might already be gone since the find()
            $old_item->delete if $old_item; # XXX might already be gone since the find()

            $item = $self->set->create($hal);
Dwarn { A => { $item->get_inflated_columns }};

            $self->response->header('Location' => $self->path_for_item($item))
                unless $old_item; # set Location and thus 201 if Created not modified
        }
        else {
            $item = $self->_update_embedded_resources($self->item, $hal, $self->item->result_class);
        }

        # called here because create_path() is too late for WM
        # and we need it to happen inside the transaction for rollback=1 to work
        # XXX requires 'self' prefetch to get any others
        $self->render_item_into_body($item)
            if $item && $self->prefetch->{self};

        $schema->txn_rollback if $self->request->param('rollback'); # XXX
    });
}

1;
