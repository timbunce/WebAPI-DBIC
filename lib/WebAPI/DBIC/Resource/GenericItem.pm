package WebAPI::DBIC::Resource::GenericItem;

=head1 NAME

WebAPI::DBIC::Resource::GenericItem - a set of roles to implement a generic DBIC item resource

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Item',
        ;

1;
