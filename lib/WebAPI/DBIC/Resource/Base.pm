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
    default => $ENV{WEBAPI_DBIC_WRITABLE},
);

has http_auth_type => (
   is => 'ro',
   default => $ENV{WEBAPI_DBIC_HTTP_AUTH_TYPE} || 'Basic',
);

has throwable => (
    is => 'rw',
    default => 'WebAPI::HTTP::Throwable::Factory',
);

has type_namer => (
   is => 'ro',
);

has serializer => (
   is => 'rw',
   lazy => 1,
   builder => '_build_serializer'
);

sub _build_serializer {
    my $self = shift;
    warn "Using WebAPI::DBIC::Serializer::Base";
    return WebAPI::DBIC::Serializer::Base->new(resource => $self);
}

1;
