package WebAPI::DBIC::Resource::GenericSetDBIC;

use Moo;
use namespace::clean;

extends 'WebAPI::DBIC::Resource::Base';
with    'WebAPI::DBIC::Role::JsonEncoder',
        'WebAPI::DBIC::Role::JsonParams',
        'WebAPI::DBIC::Resource::Role::DBIC',
        'WebAPI::DBIC::Resource::Role::DBICException',
        'WebAPI::DBIC::Resource::Role::DBICAuth',
        'WebAPI::DBIC::Resource::Role::DBICParams',
        'WebAPI::DBIC::Resource::Role::SetRender',
        'WebAPI::DBIC::Resource::Role::Set',
        'WebAPI::DBIC::Resource::Role::SetWritable',
        ;

1;
