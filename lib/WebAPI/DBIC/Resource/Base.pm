package WebAPI::DBIC::Resource::Base;

=head1 NAME

WebAPI::DBIC::Resource::Base - Base class for WebAPI::DBIC::Resource's

=head1 DESCRIPTION

This class is simply a pure subclass of WebAPI::DBIC::Resource.

=cut

use Moo;
extends 'Web::Machine::Resource';

require WebAPI::HTTP::Throwable::Factory;


has http_auth_type => (
   is => 'ro',
);

has throwable => (
    is => 'rw',
    default => 'WebAPI::HTTP::Throwable::Factory',
);


1;
