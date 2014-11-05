package WebAPI::DBIC::Resource::GenericSet;

=head1 NAME

WebAPI::DBIC::Resource::GenericSet - a set of roles to implement a generic DBIC set resource

=cut

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::GenericCore';
with    'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetHAL',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        'WebAPI::DBIC::Resource::Role::SetWritableHAL',
        ;

1;
