package WebAPI::DBIC::Resource::Role::Item;

use Moo::Role;

use Carp;
use Devel::Dwarn;

requires 'render_item_as_plain';
requires 'render_item_as_hal';
requires 'encode_json';
requires 'decode_json';

has set => (
   is => 'rw',
   required => 1,
);

has id => (
   is => 'ro',
   required => 1,
);

has item => (
   is => 'ro',
   lazy => 1,
   builder => '_build_item'
);

has writable => (
   is => 'ro',
);

has prefetch => (
   is => 'ro',
   default => sub { { } },
);

sub _build_item {
    my $self = shift;
    $self->set->find($self->id);
}


sub content_types_provided { [
    {'application/hal+json' => 'to_json_as_hal'},
    {'application/json'     => 'to_json_as_plain'},
] }

sub to_json_as_plain { $_[0]->encode_json($_[0]->render_item_as_plain($_[0]->item)) }
sub to_json_as_hal {   $_[0]->encode_json($_[0]->render_item_as_hal($_[0]->item)) }

sub resource_exists { !! $_[0]->item }

sub allowed_methods { [ qw(GET HEAD) ] }


1;
