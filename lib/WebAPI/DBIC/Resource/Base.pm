package WebAPI::DBIC::Resource::Base;

=head1 NAME

WebAPI::DBIC::Resource::Base - Base class for WebAPI::DBIC::Resource's

=head1 DESCRIPTION

This class is a subclass of WebAPI::DBIC::Resource.

=cut

use Moo;
use namespace::clean -except => [qw(meta)];
use MooX::StrictConstructor;

extends 'Web::Machine::Resource';

require WebAPI::HTTP::Throwable::Factory;

# vvv --- these allow us to use MooX::StrictConstructor
has 'request'  => (is => 'ro');
has 'response' => (is => 'ro');
sub FOREIGNBUILDARGS {
    my ($class, %args) = @_;
    return (request => $args{request}, response => $args{response});
}
# ^^^ ---

has writable => (
    is => 'ro',
);

has type_namer => (
   is => 'ro',
);

has http_auth_type => (
   is => 'ro',
   default => 'Basic',
);

has throwable => (
    is => 'rw',
    default => 'WebAPI::HTTP::Throwable::Factory',
);


1;
