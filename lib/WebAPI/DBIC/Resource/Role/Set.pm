package WebAPI::DBIC::Resource::Role::Set;

# Based on https://github.com/frioux/drinkup

use Moo::Role;

use Devel::Dwarn;

requires 'render_set_as_plain';
requires 'decode_json';
requires 'encode_json';

has set => (
   is => 'rw',
   required => 1,
);

has writable => (
   is => 'ro',
);

sub allowed_methods { [ qw(GET HEAD) ] }

sub content_types_provided { [
    {'application/hal+json' => 'to_hal_json'},
    {'application/json'     => 'to_plain_json'},
] } 

sub to_plain_json { $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }
sub to_hal_json   { $_[0]->encode_json($_[0]->render_set_as_hal(  $_[0]->set)) }

1;
