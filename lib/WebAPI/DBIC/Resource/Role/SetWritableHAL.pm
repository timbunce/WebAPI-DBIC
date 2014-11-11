package WebAPI::DBIC::Resource::Role::SetWritableHAL;

=head1 NAME

WebAPI::DBIC::Resource::Role::SetWritableHAL - methods handling HAL requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

Supports the C<application/hal+json> and C<application/json> content types.

=cut

use Devel::Dwarn;
use Carp qw(confess);

use Moo::Role;


requires '_build_content_types_accepted';
requires 'render_item_into_body';
requires 'decode_json';
requires 'set';
requires 'prefetch';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/hal+json' => 'from_hal_json' };
    return $types;
};


sub from_hal_json {
    my $self = shift;
    my $item = $self->create_resources_from_hal( $self->decode_json($self->request->content) );
    return $self->item($item);
}


sub create_resources_from_hal { # XXX unify with create_resource in SetWritable, like ItemWritable?
    my ($self, $hal) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources($hal, $self->set->result_class);

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


# recurse to create resources in $hal->{_embedded}
#   and update coresponding attributes in $hal
# then create $hal itself
sub _create_embedded_resources {
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
        my $subitem = $self->_create_embedded_resources($rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to create
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n"
            if $ENV{WEBAPI_DBIC_DEBUG};
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }
    }

    return $self->set->result_source->schema->resultset($result_class)->create($hal);
}

1;
