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
        'WebAPI::DBIC::Resource::Role::Root',
        ;

1;
