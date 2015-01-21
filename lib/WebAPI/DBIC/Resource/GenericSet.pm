package WebAPI::DBIC::Resource::GenericSet;

=head1 NAME

WebAPI::DBIC::Resource::GenericSet - a set of roles to implement a generic DBIC set resource

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        # Enable ActiveModel support:
        'WebAPI::DBIC::Resource::ActiveModel::Role::DBIC', # XXX move out?
        'WebAPI::DBIC::Resource::ActiveModel::Role::Set',
        'WebAPI::DBIC::Resource::ActiveModel::Role::SetWritable',
        # Enable HAL support:
        'WebAPI::DBIC::Resource::HAL::Role::DBIC', # XXX move out?
        'WebAPI::DBIC::Resource::HAL::Role::Set',
        'WebAPI::DBIC::Resource::HAL::Role::SetWritable',
        # Enable JSON API support:
        'WebAPI::DBIC::Resource::JSONAPI::Role::DBIC', # XXX move out?
        'WebAPI::DBIC::Resource::JSONAPI::Role::Set',
        'WebAPI::DBIC::Resource::JSONAPI::Role::SetWritable',
        ;

1;
