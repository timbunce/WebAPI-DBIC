package WebAPI::DBIC::Resource::GenericItemInvoke;

=head1 NAME

WebAPI::DBIC::Resource::GenericItemInvoke - a set of roles to implement a resource for making method calls on a DBIC item

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Role::JsonParams',
        'WebAPI::DBIC::Resource::Role::Router',
        'WebAPI::DBIC::Resource::Role::Identity', # XXX probably ought not be needed, implies need to refactor ::DBIC further
        'WebAPI::DBIC::Resource::Role::Relationship',
        'WebAPI::DBIC::Resource::Role::DBIC',
        'WebAPI::DBIC::Resource::Role::DBICException',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        'WebAPI::DBIC::Resource::Role::Item',
        'WebAPI::DBIC::Resource::Role::ItemInvoke',
        ;

1;
