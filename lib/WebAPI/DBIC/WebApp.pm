#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

BEGIN {
    $ENV{WM_DEBUG} = 0; # verbose
    $ENV{DBIC_TRACE} = 1;
    $ENV{DBI_TRACE} = 0;
    $ENV{PATH_ROUTER_DEBUG} = 0;
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

    my $rs = $schema->resultset($resultset);
    return (
        "$path" => {
            resultset => $rs->search_rs(undef, {
                # XXX default attributes
                rows => 30,
                page => 1,
                order_by => { -asc => [ $rs->result_source->primary_columns ] },
            }),
            getargs => sub {
                my ($request, $rs, $id) = @_;
                $rs = $rs->page($request->param('page') || 1);
                return { set => $rs }
            },
            resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        },
        "$path/:id" => {
            validations => { id => qr/^\d+$/ },
            resultset => $rs,
            getargs => sub { my ($request, $rs, $id) = @_; return { item => $rs->find($id) } },
            resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
        }
    );
}

my @routes;
push @routes, mk_generic_dbic_item_set_route_pair(
    'person_types' => 'PersonType'
);
push @routes, mk_generic_dbic_item_set_route_pair(
    'persons' => 'People'
);
push @routes, mk_generic_dbic_item_set_route_pair(
    'client_auths' => 'ClientAuth'
);
push @routes, mk_generic_dbic_item_set_route_pair(
    'ecosystems_people' => 'EcosystemsPeople'
);


my $router = Path::Router->new;
while (my $r = shift @routes) {
    my $spec = shift @routes or die "panic";

    my $rs = $spec->{resultset};
    my $getargs = $spec->{getargs};
    my $writable = (exists $spec->{writable}) ? $spec->{writable} : $opt_writable;
    my $resource_class = $spec->{resource} or die "panic";
    load $resource_class;
    my $in_production = ($ENV{TL_ENVIRONMENT} ne 'production');

    $router->add_route($r,
        validations => $spec->{validations} || {},
        target => sub {
            my $request = shift; # url args remain in @_
            my $args = $getargs ? $getargs->($request, $rs, @_) : {};
#warn "$r: args @{[%$args]}";
#$DB::single=1;
            my $app = WebAPI::DBIC::Machine->new(
                resource => $resource_class,
                debris   => {
                    set => $rs,
                    writable => $writable,
                    %$args
                },
                tracing => !$in_production,
            )->to_app;
#local $SIG{__DIE__} = \&Carp::confess;
            my $resp = $app->($request->env);
            #Dwarn $resp;
            return $resp;
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

    my $root_data = {
        _links => \%links,
    };

    $router->add_route('',
        target => sub {
            my $request = shift;
            [ 200, [], [ JSON->new->ascii->pretty->encode($root_data) ] ]
        },
    );
}

# XXX should be moved elsewhere, perhaps to a .psgi file
use Plack::Builder;
use Plack::App::File;
builder {
    enable 'SimpleLogger';  # show on STDERR
    mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
    mount "/" => Plack::App::Path::Router->new( router => $router );
};
