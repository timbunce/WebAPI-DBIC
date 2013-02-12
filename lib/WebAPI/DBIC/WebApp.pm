#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

BEGIN {
    $ENV{WM_DEBUG} = 1; # verbose
    $ENV{DBIC_TRACE} = 1;
    $ENV{DBI_TRACE} = 0;
    $ENV{PATH_ROUTER_DEBUG} = 1;
}

use Web::Simple;
use Plack::App::Path::Router;
use Path::Class::File;
use Path::Router;
use Module::Load;
use JSON;

use Devel::Dwarn;

use WebAPI::Schema::Corp;
use WebAPI::DBIC::Machine;

my $opt_writable = 1;

my $schema = WebAPI::Schema::Corp->new_default_connect(
    {},
    # connect to yesterdays snapshot because we make edits to the db
    # XXX should really have a better approach for this!
    "corp_snapshot_previous",
);


sub mk_generic_dbic_item_set_route_pair {
    my ($path, $resultset) = @_;
    return (
        "$path" => {
            resultset => $resultset,
            resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        },
        "$path/:id" => {
            validations => { id => qr/^\d+$/ },
            resultset => $resultset,
            resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
            getargs => sub { my ($request, $rs, $id) = @_; return { item => $rs->find($id) } },
        }
    );
}

my @routes;
push @routes, mk_generic_dbic_item_set_route_pair(
    'person_types' => 'PersonType'
);


my $router = Path::Router->new;
while (my $r = shift @routes) {
    my $spec = shift @routes or die "panic";

    my $rs = $schema->resultset($spec->{resultset});
    my $getargs = $spec->{getargs};
    my $writable = (exists $spec->{writable}) ? $spec->{writable} : $opt_writable;
    my $resource_class = $spec->{resource} or die "panic";
    load $resource_class;

    $router->add_route($r,
        validations => $spec->{validations} || {},
        target => sub {
            my $request = shift; # url args remain in @_
            my $args = $getargs ? $getargs->($request, $rs, @_) : {};
            my $app = WebAPI::DBIC::Machine->new(
                resource => $resource_class,
                debris   => {
                    set => $rs,
                    writable => $writable,
                    %$args
                },
                tracing => 0,
            )->to_app;
            $app->($request->env);
        },
    );
};

if (1) {
    my %links = (self => { href => "/" } );

    my @resource_links;
    foreach my $route (@{$router->routes})  {
        my @parts;
        my %attr;
        for my $c (@{ $route->components }) {
            if ($route->is_component_variable($c)) {
                my $name = $route->get_component_name($c);
                push @parts, "{/$name}";
                $attr{templated} = JSON::true;
            } else {
                push @parts, "/$c";
            }
        }
        my $url = join("", @parts);
        $links{$url} = {
            href => $url,
            %attr
        };
    }
    #$links{resource_links} = \@resource_links;

=pod
  "_links": {
    "self": { "href": "/orders" },
    "next": { "href": "/orders?page=2" },
    "find": { "href": "/orders{?id}", "templated": true },
    "admin": [
      { "href": "/admins/2", "title": "Fred" },
      { "href": "/admins/5", "title": "Kate" }
    ]
  },
=cut

    my $root_data = {
        _links => \%links,
    };

    $router->add_route('',
        target => sub {
            my $request = shift;
            [ 200, [], [ JSON->new->pretty->encode($root_data) ] ]
        },
    );
}

# XXX should be moved elsewhere, perhaps to a .psgi file
use Plack::Builder;
use Plack::App::File;
builder {
    mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
    mount "/" => Plack::App::Path::Router->new( router => $router );
};
