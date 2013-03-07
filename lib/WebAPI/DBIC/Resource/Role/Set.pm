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
    # call render_item_into_body here because create_path is too late
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

sub create_resources_from_hal {
    my ($self, $hal) = @_;
    my $links    = delete $hal->{_links};
    my $meta     = delete $hal->{_meta};
    my $embedded = delete $hal->{_embedded} || {};
    my $item;

    my $schema = $self->set->schema;
    # XXX perhaps the transaction wrapper belongs higher in the stack
    $schema->txn_do(sub {

        for my $rel (keys %$embedded) {
            my $rel_obj = $embedded->{$rel};
            # XXX this ought to recurse - we'd need to create temp WMs for each (via path router)
            warn "create_resources_from_hal $rel";
            # lookup relation and check its supported (single etc)
            # find rel key field(s) and check embedded data and $hal don't define key value
            # create the rel object in the db
            # set the corresponding $hal fields for the created key
        }

        # finally create the primary resource
        $item = $self->create_resource($hal);

        $schema->txn_rollback if $self->request->param('rollback'); # XXX
    });

    return $item;
}

sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}

1;
