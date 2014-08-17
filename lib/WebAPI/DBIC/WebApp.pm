#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

use strict;
use warnings;

use Module::Runtime qw(use_module);
use Carp qw(croak confess);
use JSON::MaybeXS qw(JSON);

use Devel::Dwarn;

use WebAPI::DBIC::Machine;
use WebAPI::HTTP::Throwable::Factory;

# pre-load some modules to improve shared memory footprint
require DBIx::Class::SQLMaker;

use Moo;
use namespace::clean;


has schema => (is => 'ro', required => 1);
has writable => (is => 'ro', default => 1);
has http_auth_type => (is => 'ro', default => 'Basic');
has extra_routes => (is => 'ro', lazy => 1, builder => 1);
has auto_routes => (is => 'ro', lazy => 1, builder => 1);
has router_class => (is => 'ro', builder => 1);

sub _build_router_class {
    require WebAPI::DBIC::Router;
    return 'WebAPI::DBIC::Router';
}

sub _build_extra_routes { [] }
sub _build_auto_routes {
    my ($self) = @_;

    my @routes;
    for my $source_names ($self->schema->sources) {

        my $result_source = $self->schema->source($source_names);
        my $result_name = $result_source->name;
        $result_name = $$result_name if (ref($result_name) eq 'SCALAR');

        next unless $result_name =~ /^[\w\.]+$/x;

        my %opts;
        # this is a hack just to enable testing, eg t/60-invoke.t
        push @{$opts{invokeable_on_item}}, 'get_column'
            if $self->schema->resultset($result_source->source_name)
                ->result_class =~ /^TestSchema::Result/;

        # these become args to mk_generic_dbic_item_set_routes
        push @routes, [
            $result_name => $result_source->source_name, %opts
        ];
    }

    return \@routes;
}


sub hal_browser_app {
    my $request = shift;
    my $router = $request->env->{'plack.router'};
    my $path = $request->env->{REQUEST_URI}; # "/clients/v1/";

    # if the request for the root url is from a browser
    # then redirect to the HAL browser interface
    return [ 302, [ Location => "browser/browser.html#$path" ], [ ] ]
        if $request->headers->header('Accept') =~ /html/;

    # we get here when the HAL Browser requests the root JSON
    my %links = (self => { href => $path } );
    foreach my $route (@{$router->routes})  {
        my @parts;
        my %attr;

        for my $c (@{ $route->components }) {
            if ($route->is_component_variable($c)) {
                my $name = $route->get_component_name($c);
                push @parts, "{/$name}";
                $attr{templated} = JSON->true;
            } else {
                push @parts, "$c";
            }
        }
        next unless @parts;

        my $url = $path . join("", @parts);
        $links{join("", @parts)} = {
            href => $url,
            title => $route->defaults->{_title}||"",
            %attr
        };
    }
    my $root_data = { _links => \%links, };

    return [ 200, [ 'Content-Type' => 'application/json' ],
        [ JSON->new->ascii->pretty->encode($root_data) ]
    ]
}


sub mk_generic_dbic_item_set_routes {
    my ($self, $path, $resultset, %opts) = @_;

    my $rs = $self->schema->resultset($resultset);

    # XXX might want to distinguish writable from non-writable (read-only) methods
    my $invokeable_on_set  = delete $opts{invokeable_on_set}  || [];
    my $invokeable_on_item = delete $opts{invokeable_on_item} || [];
    # disable all methods if not writable, for safety: (perhaps allow get_* methods)
    $invokeable_on_set  = [] unless $self->writable;
    $invokeable_on_item = [] unless $self->writable;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "Auto routes for /%s => resultset %s, result_class %s\n",
            $path, $resultset, $rs->result_class;
    }

    my $qr_names = sub {
        my $names_r = join "|", map { quotemeta $_ } @_ or confess "panic";
        return qr/^(?:$names_r)$/x;
    };

    my $route_defaults = {
        # --- fields for route lookup
        result_class => $rs->result_class,
        # --- fields for other uses
        # derive title from result class: WebAPI::Corp::Result::Foo => "Corp Foo"
        _title => join(" ", (split /::/, $rs->result_class)[-3,-1]),
    };
    my $mk_getargs = sub {
        my @params = @_;
        # XXX we should try to generate more efficient code here
        return sub {
            my $req = shift;
            my $args = shift;
            $args->{set} = $rs; # closes over $rs above
            for (@params) { #in path param name order
                if (m/^[0-9]+$/) { # an id field
                    $args->{id}[$_-1] = shift @_;
                }
                else {
                    $args->{$_} = shift @_;
                }
            }
        }
    };
    my @routes;

    push @routes, "$path" => { # set (aka collection)
        resource_class => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->(),
    };

    push @routes, "$path/invoke/:method" => { # method call on set
        validations => { method => $qr_names->(@$invokeable_on_set) },
        resource_class => 'WebAPI::DBIC::Resource::GenericSetInvoke',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->('method'),
    } if @$invokeable_on_set;


    my $item_resource_class = 'WebAPI::DBIC::Resource::GenericItemDBIC';
    use_module $item_resource_class;
    my @key_fields = $rs->result_source->unique_constraint_columns( $item_resource_class->id_unique_constraint_name );
    my @idn_fields = 1 .. @key_fields;
    my $item_path_spec = join "/", map { ":$_" } @idn_fields;

    push @routes, "$path/$item_path_spec" => { # item
        #validations => { },
        resource_class => $item_resource_class,
        route_defaults => $route_defaults,
        getargs => $mk_getargs->(@idn_fields),
    };

    push @routes, "$path/$item_path_spec/invoke/:method" => { # method call on item
        validations => {
            method => $qr_names->(@$invokeable_on_item),
        },
        resource_class => 'WebAPI::DBIC::Resource::GenericItemInvoke',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->(@idn_fields, 'method'),
    } if @$invokeable_on_item;

    return @routes;
}

sub all_routes {
    my ($self) = @_;
    return map {
        $self->mk_generic_dbic_item_set_routes(@$_)
    } (@{ $self->auto_routes }, @{ $self->extra_routes });
}

sub to_psgi_app {
    my ($self) = @_;

    my $router = $self->router_class->new;

    my @routes = $self->all_routes;

    while (my $path = shift @routes) {
        my $spec = shift @routes or confess "panic";

        $self->add_webapi_dbic_route($router, $path, $spec);
    }

    $router->add_route(path => '', target => \&hal_browser_app);

    return $router->to_psgi_app; # return Plack app
}


sub add_webapi_dbic_route {
    my ($self, $router, $path, $spec) = @_;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "/%s => result_class=%s, via %s\n", $path,
            $spec->{route_defaults}{result_class},
            $spec->{resource_class};
    }

    my $getargs = $spec->{getargs};
    my $resource_class = $spec->{resource_class} or confess "panic";
    use_module $resource_class;
    
    # this sub acts as the interface between the router and
    # the WebAPI::DBIC::Machine instance handling the resource for that url path
    my $target = sub {
        my $request = shift; # url args remain in @_

        #local $SIG{__DIE__} = \&Carp::confess;

        my %resource_args;
        # perform any required setup for this request & params in @_
        $getargs->($request, \%resource_args, @_) if $getargs;

        warn "$path: running machine for $resource_class (with @{[ keys %resource_args ]})\n"
            if $ENV{WEBAPI_DBIC_DEBUG};

        my $app = WebAPI::DBIC::Machine->new(
            resource => $resource_class,
            debris   => {
                writable => $self->writable,
                http_auth_type => $self->http_auth_type,
                throwable => 'WebAPI::HTTP::Throwable::Factory',
                %resource_args,
            },
            tracing => $ENV{WEBAPI_DBIC_DEBUG},
        )->to_app;

        my $resp = eval { $app->($request->env) };
        #Dwarn $resp;
        if ($@) { # XXX report and rethrow
            warn "EXCEPTION during request for $path: $@";
            die; ## no critic (ErrorHandling::RequireCarping)
        }

        return $resp;
    };

    $router->add_route(
        path        => $path,
        validations => $spec->{validations} || {},
        defaults    => $spec->{route_defaults},
        target      => $target,
    );

    return;
}

1;
__END__
