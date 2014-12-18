package WebAPI::DBIC::WebApp;

=head1 NAME

WebAPI::DBIC::WebApp - Build a Plack app using WebAPI::DBIC

=head1 SYNOPSIS

This most simple example:

    $app = WebAPI::DBIC::WebApp->new({
        schema => $schema,
    })->to_psgi_app;

is the same as:

    $app = WebAPI::DBIC::WebApp->new({
        schema => $schema,
        routes => [ $schema->sources ],
    })->to_psgi_app;

which is the same as:

    $app = WebAPI::DBIC::WebApp->new({
        schema => $schema,
        route_maker => WebAPI::DBIC::RouteMaker->new(
            schema => $schema,
            type_name_inflect => 'singular',    # XXX will change to plural soon
            type_name_style   => 'under_score', # or 'camelCase' etc
            resource_class_for_item        'WebAPI::DBIC::Resource::GenericItem',
            resource_class_for_item_invoke 'WebAPI::DBIC::Resource::GenericItemInvoke',
            resource_class_for_set         'WebAPI::DBIC::Resource::GenericSet',
            resource_class_for_set_invoke  'WebAPI::DBIC::Resource::GenericSetInvoke',
        ),
        routes => [ $schema->sources ],
    })->to_psgi_app;

The elements in C<routes> are passed to the specified C<route_maker>.
The elements can include any mix of result source names, as in the example above,
resultset objects, and L<WebAPI::DBIC::Route> objects.

Result source names are converted to resultset objects.

The L<WebAPI::DBIC::RouteMaker> object converts the resultset objects
into a set of WebAPI::DBIC::Routes, e.g, C<foo/> for the resultset and
C<foo/:id> for an item of the set.

The path prefix, i.e., C<foo> is determined from the resultset using the
C<type_name_inflect> and C<type_name_style> to define the route path, and the
C<resource_class_for_*> to define the resource classes that the routes should
refer to.

=cut

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
