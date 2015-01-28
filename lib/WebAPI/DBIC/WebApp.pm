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
        routes => [ $schema->sources ],
        route_maker => WebAPI::DBIC::RouteMaker->new(
            resource_class_for_item        => 'WebAPI::DBIC::Resource::GenericItem',
            resource_class_for_item_invoke => 'WebAPI::DBIC::Resource::GenericItemInvoke',
            resource_class_for_set         => 'WebAPI::DBIC::Resource::GenericSet',
            resource_class_for_set_invoke  => 'WebAPI::DBIC::Resource::GenericSetInvoke',
            resource_default_args          => { },
            type_namer => WebAPI::DBIC::TypeNamer->new( # EXPERIMENTAL
                type_name_inflect => 'singular',    # XXX will change to plural soon
                type_name_style   => 'under_score', # or 'camelCase' etc
            ),
        ),
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
use Safe::Isa;

use namespace::clean -except => [qw(meta)];
use MooX::StrictConstructor;

use Web::Machine;

use WebAPI::DBIC::RouteMaker;
use WebAPI::DBIC::Router;
use WebAPI::DBIC::Route;


has schema => (is => 'ro', required => 1);

has routes => (
    is => 'ro',
    lazy => 1,
    default => sub { [ sort shift->schema->sources ] },
);

has extra_routes => (
    is => 'ro',
    default => sub { [] },
);

has route_maker => (
    is => 'ro',
    lazy => 1,
    builder => 1,
    isa => sub {
        die "$_[0] is not a WebAPI::DBIC::RouteMaker" unless $_[0]->$_isa('WebAPI::DBIC::RouteMaker');
    },
);

sub _build_route_maker {
    my ($self) = @_;

    return WebAPI::DBIC::RouteMaker->new();
}



sub to_psgi_app {
    my ($self) = @_;

    my $router = WebAPI::DBIC::Router->new(extra_routes => $self->extra_routes);

    # set the route_maker schema here so users don't have
    # to set schema in both WebApp and RouteMaker
    $self->route_maker->schema($self->schema);

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
