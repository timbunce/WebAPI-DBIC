package WebAPI::DBIC::Resource::Role::SetWritable;

# Based on https://github.com/frioux/drinkup

use Moo::Role;

use Devel::Dwarn;

requires 'render_set_as_plain';
requires 'render_item_into_body';
requires 'decode_json';
requires 'encode_json';
requires 'set';
requires 'prefetch';
requires 'writable';
requires 'path_for_item';


has item => ( # for POST to create
    is => 'rw',
);


around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;

    my $methods = $self->$orig();

    push @$methods, 'POST' if $self->writable;

    return $methods;
};


sub post_is_create { 1 }

sub create_path_after_handler { 1 }

sub content_types_accepted { [
    {'application/hal+json' => 'from_hal_json'},
    {'application/json'     => 'from_plain_json'}
] }

sub from_plain_json {
    my $self = shift;
    $self->item($self->create_resource($self->decode_json($self->request->content)));
}

sub from_hal_json {
    my $self = shift;
    $self->item($self->create_resources_from_hal($self->decode_json($self->request->content)));
}


sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}


sub create_resource {
    my ($self, $data) = @_;
    my $item = $self->set->create($data);
    # called here because create_path() is too late for Web::Machine
    $self->render_item_into_body($item) if $self->prefetch->{self};
    return $item;
}


sub create_resources_from_hal {
    my ($self, $hal) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources($hal, $self->set->result_class);

        # called here because create_path() is too late for Web::Machine
        # and we need it to happen inside the transaction for rollback=1 to work
        $self->render_item_into_body($item)
            if $item && $self->prefetch->{self};

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
            or die "$result_class doesn't have a '$rel' relation";
        die "$result_class $rel isn't a single"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_hal = $embedded->{$rel};
        die "$rel data is not a hash"
            if ref $rel_hal ne 'HASH';

        # work out what keys to copy from the subitem we're about to create
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

        # create this subitem (and any resources embedded in it)
        my $subitem = $self->_create_embedded_resources($rel_hal, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to create
        warn "$result_class $rel: propagating keys: @{[ %fk_map ]}\n";
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }
    }

    return $self->set->result_source->schema->resultset($result_class)->create($hal);
}

1;
