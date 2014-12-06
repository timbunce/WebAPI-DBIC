package WebAPI::DBIC::Resource::GenericItem;

=head1 NAME

WebAPI::DBIC::Resource::GenericItem - a set of roles to implement a generic DBIC item resource

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Item',
        'WebAPI::DBIC::Resource::Role::ItemWritable',
        # Enable HAL support:
        'WebAPI::DBIC::Resource::HAL::Role::DBIC',
        'WebAPI::DBIC::Resource::HAL::Role::Item',
        'WebAPI::DBIC::Resource::HAL::Role::ItemWritable',
        # Enable JSON API support:
        'WebAPI::DBIC::Resource::JSONAPI::Role::DBIC',
        'WebAPI::DBIC::Resource::JSONAPI::Role::Item',
        'WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable',
        ;

1;
