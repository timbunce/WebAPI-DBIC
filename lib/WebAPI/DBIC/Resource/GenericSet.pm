package WebAPI::DBIC::Resource::GenericSet;

=head1 NAME

WebAPI::DBIC::Resource::GenericSet - a set of roles to implement a generic DBIC set resource

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        # Enable HAL support:
        'WebAPI::DBIC::Resource::Role::DBIC_HAL', # XXX move out?
        'WebAPI::DBIC::Resource::Role::SetHAL',
        'WebAPI::DBIC::Resource::Role::SetWritableHAL',
        # Enable JSON API support:
        'WebAPI::DBIC::Resource::Role::DBIC_JSONAPI', # XXX move out?
        'WebAPI::DBIC::Resource::Role::SetJSONAPI',
        'WebAPI::DBIC::Resource::Role::SetWritableJSONAPI',
        ;

1;
