package WebAPI::DBIC::Resource::GenericItemInvoke;

use Moo;

extends 'Web::Machine::Resource';
with 'WebAPI::DBIC::Role::JsonEncoder';
with 'WebAPI::DBIC::Role::JsonParams';
with 'WebAPI::DBIC::Resource::Role::DBIC';
with 'WebAPI::DBIC::Resource::Role::Item';
with 'WebAPI::DBIC::Resource::Role::ItemInvoke';
with 'WebAPI::DBIC::Resource::Role::DBICParams';
with 'WebAPI::DBIC::Resource::Role::DBICAuth';

1;
