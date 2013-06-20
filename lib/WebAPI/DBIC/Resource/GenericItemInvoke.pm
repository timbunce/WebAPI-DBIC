package WebAPI::DBIC::Resource::GenericItemInvoke;

use Moo;

extends 'Web::Machine::Resource';

with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Role::JsonParams',
        'WebAPI::DBIC::Resource::Role::DBIC',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        'WebAPI::DBIC::Resource::Role::Item',
        'WebAPI::DBIC::Resource::Role::ItemInvoke',
        ;

1;
