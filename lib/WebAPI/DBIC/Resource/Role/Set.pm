package WebAPI::DBIC::Resource::Role::Set;

# Based on https://github.com/frioux/drinkup

use Moo::Role;

use Devel::Dwarn;

requires 'render_set_as_plain';
requires 'decode_json';
requires 'encode_json';

has set => (
   is => 'ro',
   required => 1,
);

has item => ( # POST
   is => 'rw',
);    

has writable => (
   is => 'ro',
);

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable ) ? (qw(POST)) : ()
   ]
}

sub post_is_create { 1 }

sub create_path_after_handler { 1 }

sub content_types_provided { [
    {'application/hal+json' => 'to_hal_json'},
    {'application/json'     => 'to_plain_json'},
] } 

sub content_types_accepted { [
    {'application/hal+json' => 'from_hal_json'},
    {'application/json'     => 'from_plain_json'}
] }

sub to_plain_json { $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }
sub to_hal_json   { $_[0]->encode_json($_[0]->render_set_as_hal(  $_[0]->set)) }

sub from_plain_json {
    my $self = shift;
    $self->item($self->create_resource($self->decode_json($self->request->content)));
}

sub from_hal_json {
    my $self = shift;
    $self->item($self->create_resources_from_hal($self->decode_json($self->request->content)));
}

sub create_resource {
    my ($self, $data) = @_;
    my $item = $self->set->create($data);
    # called here because create_path() is too late for WM
    $self->render_item_into_body($item) if $self->prefetch->{self};
    return $item;
}

sub render_item_into_body {
    my ($self, $item) = @_;
    # XXX ought to be a dummy request?
    my $item_request = $self->request;
    # XXX shouldn't hard-code GenericItemDBIC here
    my $item_resource = WebAPI::DBIC::Resource::GenericItemDBIC->new(
        request => $item_request, response => $item_request->new_response,
        set => $self->set, item => $item,
    );
    $self->response->body( $item_resource->to_json_as_hal );

    return;
}


# recurse to create resources in $hal->{_embedded}
#   and update coresponding attributes in $hal
# then create $hal itself
sub _create_embedded_resources {
    my ($self, $hal, $class) = @_;

    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};

    for my $rel (keys %$embedded) {

        my $rel_info = $class->relationship_info($rel)
            or die "$class doesn't have a '$rel' relation";
        die "$class $rel isn't a single"
            if $rel_info->{attrs}{accessor} ne 'single';

        my $rel_obj = $embedded->{$rel};
        die "$rel data is not a hash"
            if ref $rel_obj ne 'HASH';

        # work out what keys to copy from the subitem we're about to create
        my %fk_map;
        my $cond = $rel_info->{cond};
        for my $sub_field (keys %$cond) {
            my $our_field = $cond->{$sub_field};
            $our_field =~ s/^self\.//    or die "panic $rel $our_field";
            $sub_field =~ s/^foreign\.// or die "panic $rel $sub_field";
            $fk_map{$our_field} = $sub_field;

            die "$class already contains a value for '$our_field'\n"
                if defined $hal->{$our_field}; # null is ok
        }

        # create this subitem (and any resources embedded in it)
        my $subitem = $self->_create_embedded_resources($rel_obj, $rel_info->{source});

        # copy the keys of the subitem up to the item we're about to create
        while ( my ($ourfield, $subfield) = each %fk_map) {
            $hal->{$ourfield} = $subitem->$subfield();
        }
    }

    return $self->set->result_source->schema->resultset($class)->create($hal);
}


sub create_resources_from_hal {
    my ($self, $hal) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources($hal, $self->set->result_class);

        $schema->txn_rollback if $self->request->param('rollback'); # XXX
    });

    # called here because create_path() is too late for WM
    $self->render_item_into_body($item) if $self->prefetch->{self};

    return $item;
}


sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}

1;
