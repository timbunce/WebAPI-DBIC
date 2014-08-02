package WebAPI::DBIC::Resource::Role::Item;

use Moo::Role;


requires 'render_item_as_plain_hash';
requires 'render_item_as_hal_hash';
requires 'id_unique_constraint_name';
requires 'key_values_from_id';
requires 'encode_json';
requires 'set';


has id => (         # :id from url path
   is => 'ro',
   required => 1,
);

has item => (
   is => 'ro',
   lazy => 1,
   builder => '_build_item'
);

sub _build_item {
    my $self = shift;
    return $self->set->find(
        $self->key_values_from_id($self->id),
        { key => $self->id_unique_constraint_name }
    )
}


sub content_types_provided { return [
    {'application/hal+json' => 'to_json_as_hal'},
    {'application/json'     => 'to_json_as_plain'},
] }

sub to_json_as_plain { return $_[0]->encode_json($_[0]->render_item_as_plain_hash($_[0]->item)) }
sub to_json_as_hal {   return $_[0]->encode_json($_[0]->render_item_as_hal_hash($_[0]->item)) }

sub resource_exists { return !! $_[0]->item }

sub allowed_methods { return [ qw(GET HEAD) ] }


1;
