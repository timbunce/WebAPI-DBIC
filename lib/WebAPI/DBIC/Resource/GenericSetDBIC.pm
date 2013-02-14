package WebAPI::DBIC::Resource::GenericSetDBIC;

use Moo;

extends 'Web::Machine::Resource';
with 'WebAPI::DBIC::Role::JsonEncoder';
with 'WebAPI::DBIC::Resource::Role::DBIC';
with 'WebAPI::DBIC::Resource::Role::Set';
with 'WebAPI::DBIC::Resource::Role::DBICAuth';

1;
