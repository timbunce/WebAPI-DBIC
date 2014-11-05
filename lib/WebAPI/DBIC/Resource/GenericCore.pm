package WebAPI::DBIC::Resource::GenericCore;

=head1 NAME

WebAPI::DBIC::Resource::GenericCore - a set of core roles to implement a generic DBIC resources

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Role::JsonParams',
        'WebAPI::DBIC::Resource::Role::Router',
        'WebAPI::DBIC::Resource::Role::Identity',
        'WebAPI::DBIC::Resource::Role::Relationship',
        'WebAPI::DBIC::Resource::Role::DBIC',
        'WebAPI::DBIC::Resource::Role::DBIC_HAL', # XXX move out?
        'WebAPI::DBIC::Resource::Role::DBICException',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        ;

1;
