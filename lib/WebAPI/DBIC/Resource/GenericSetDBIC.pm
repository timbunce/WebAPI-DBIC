package WebAPI::DBIC::Resource::GenericSetDBIC;

=head1 NAME

WebAPI::DBIC::Resource::GenericSetDBIC - a set of roles to implement a generic DBIC set resource

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
        'WebAPI::DBIC::Resource::Role::DBICException',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        'WebAPI::DBIC::Resource::Role::SetRender',
        'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        ;

1;
