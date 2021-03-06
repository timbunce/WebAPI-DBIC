package WebAPI::DBIC::Resource::GenericItemInvoke;

=head1 NAME

WebAPI::DBIC::Resource::GenericItemInvoke - a set of roles to implement a resource for making method calls on a DBIC item

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Item',
        'WebAPI::DBIC::Resource::Role::ItemInvoke',
        ;

1;
