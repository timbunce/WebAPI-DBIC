package WebAPI::DBIC::Serializer::WAPID;

=head1 NAME

WebAPI::DBIC::Serializer::WAPID - Serializer for WebAPI::DBIC's own test media type

=cut

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';

1;
