package WebAPI::DBIC::Resource::GenericSetInvoke;

=head1 NAME

WebAPI::DBIC::Resource::GenericSetInvoke - a set of roles to implement a resource for making method calls on a DBIC item

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetInvoke',
        ;

1;
