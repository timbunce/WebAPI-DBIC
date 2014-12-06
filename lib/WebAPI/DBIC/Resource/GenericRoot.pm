package WebAPI::DBIC::Resource::GenericRoot;

=head1 NAME

WebAPI::DBIC::Resource::GenericRoot - a set of roles to implement a 'root' resource describing the application

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Resource::Role::Router',
        'WebAPI::DBIC::Resource::Role::DBICException',
        # for application/hal+json
        'WebAPI::DBIC::Resource::Role::Root',
        'WebAPI::DBIC::Resource::HAL::Role::Root',
        ;

1;
