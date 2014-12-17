package WebAPI::DBIC::WebApp;

use Moo;

use Module::Runtime qw(use_module);
use Carp qw(croak confess);
use Devel::Dwarn;

use Web::Machine;

use WebAPI::DBIC::RouteMaker;
use WebAPI::DBIC::Router;
use WebAPI::DBIC::Route;

use namespace::clean;


has schema => (is => 'ro', required => 1);
has route_maker => (is => 'ro', lazy => 1, builder => 1);
has resource_default_args => (
    is => 'ro',
    default => sub { {
        writable => 1, # XXX move to TestDS
    } });

has routes => (
    is => 'ro',
    lazy => 1,
    default => sub { [ shift->schema->sources ] },
);


sub _build_route_maker {
    my ($self) = @_;

    return WebAPI::DBIC::RouteMaker->new(
        schema => $self->schema,
        resource_default_args => $self->resource_default_args,
    );
}


sub to_psgi_app {
    my ($self) = @_;

    my $router = WebAPI::DBIC::Router->new; # XXX

    for my $route_spec (@{ $self->routes }) {

        for my $route ($self->route_maker->make_routes_for($route_spec)) {

            $router->add_route( $route->as_add_route_args );

        }
    }

    if (not $router->match('/')) {
        $router->add_route( $self->route_maker->make_root_route->as_add_route_args );
    }

    return $router->to_psgi_app; # return Plack app
}


1;
__END__
