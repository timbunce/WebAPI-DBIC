package WebAPI::DBIC::Resource::Role::Item;

use Moo::Role;

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
    # discard hal attributes
    delete $data->{_links};
    delete $data->{_embedded};
    $self->update_resource($data);
    $self->response->body( $self->to_json_as_hal )
        if $self->prefetch->{self};
}

sub resource_exists { !! $_[0]->item }

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable || 1 ) ? (qw(PUT DELETE)) : ()
   ]
}

sub delete_resource { $_[0]->item->delete }

sub update_resource { $_[0]->item->update($_[1]) }

1;
