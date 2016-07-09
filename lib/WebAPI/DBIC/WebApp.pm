package WebAPI::DBIC::WebApp;

=head1 NAME

WebAPI::DBIC::WebApp - Build a Plack app using WebAPI::DBIC

=head1 SYNOPSIS

This minimal example creates routes for all data sources in the schema:

    $app = WebAPI::DBIC::WebApp->new({
        routes => [ map( $schema->source($_), $schema->sources) ]
    })->to_psgi_app;

is the same as:

    $app = WebAPI::DBIC::WebApp->new({
        routes => [
            { set => $schema->source('Artist') },
            { set => $schema->source('CD') },
            { set => $schema->source('Genre') },
            { set => $schema->source('Track') },
            ...
        ]
    })->to_psgi_app;

which is the same as:

    $app = WebAPI::DBIC::WebApp->new({
        routes => [
            ... # as above
        ],
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
The elements can include any mix of result source objects, as in the example
above, resultset objects, and L<WebAPI::DBIC::Route> objects.

WebAPI::DBIC::WebApp uses the L<WebAPI::DBIC::RouteMaker> object to convert and
expands the given C<routes> into a corresponding set of WebAPI::DBIC::Routes.
For example, if we gloss over some details along the way, a C<routes>
specification like this:

    routes => [
        $schema->source('CD'),
    ]

is a short-hand way of writing this:

    routes => [
        { set => $schema->source('CD'), path => undef, ... }
    ]

is a short-hand way of writing this:

    routes => [
        $route_maker->make_routes_for( { set => $schema->source('CD'), ... } )
    ]

which is a short-hand way of writing this:

    $cd_resultset = $schema->source('CD')->resultset;
    $cd_path = $type_namer->type_name_for_resultset($cd_resultset);
    routes => [
        $route_maker->make_routes_for_resultset($cd_path, $cd_resultset, ...)
    ]

which is a short-hand way of writing this:

    $cd_resultset = $schema->source('CD')->resultset;
    $cd_path = $type_namer->type_name_for_resultset($cd_resultset);
    routes => [
        $route_maker->make_routes_for_set($cd_path, $cd_resultset),  # /cd
        $route_maker->make_routes_for_item($cd_path, $cd_resultset), # /cd/:id
    ]

which is a short-hand way of writing something much longer with explicit calls
to create the fully specified L<WebAPI::DBIC::Route> objects.

The I<default> URL path prefix is determined by the C<type_namer> from the
resultset source name using the C<type_name_inflect> and C<type_name_style> settings.
For example, a result source name of C<ClassicAlbum> would have a URL path
prefix of C</classic_albums> by default, i.e. plural, and lowercased with
underscores between words.

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


has routes => (
    is => 'ro',
    required => 1,
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
