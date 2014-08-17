package WebAPI::DBIC::Router;

=head1 NAME

WebAPI::DBIC::Router - Route URL paths to resources

=head1 DESCRIPTION

This is currently a subclass of L<Path::Router>.

The intention is to support other routers.

=cut

use Moo;
extends 'Path::Router';

use Plack::App::Path::Router;
use Carp qw(croak);


sub add_webapi_dbic_route {
    my ($self, %args) = @_;

    my $path        = delete $args{path}        or croak "path not specified";
    my $validations = delete $args{validations} or croak "validations not specified";
    my $defaults    = delete $args{defaults}    or croak "defaults not specified";
    my $target      = delete $args{target}      or croak "target not specified";
    croak "Unknown params (@{[ sort keys %args ]})" if %args;

    $self->add_route($path,
        validations => $validations,
        defaults => $defaults,
        target => $target,
    );
}

sub to_psgi_app {
    my $self = shift;
    return Plack::App::Path::Router->new( router => $self )->to_app; # return Plack app
}

1;
