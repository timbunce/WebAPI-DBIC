package WebAPI::DBIC::Resource::GenericItemDBIC;

use Moo;

extends 'Web::Machine::Resource';
with 'WebAPI::DBIC::Role::JsonEncoder';
with 'WebAPI::DBIC::Role::JsonParams';
with 'WebAPI::DBIC::Resource::Role::DBIC';
with 'WebAPI::DBIC::Resource::Role::Item';
with 'WebAPI::DBIC::Resource::Role::ItemWritable';
with 'WebAPI::DBIC::Resource::Role::DBICParams';
with 'WebAPI::DBIC::Resource::Role::DBICAuth';

1;
