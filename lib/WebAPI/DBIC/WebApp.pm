#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

use strict;
use warnings;

use Plack::App::Path::Router;
use Path::Router;
use Module::Load;
use Carp qw(croak confess);
use JSON;

use Devel::Dwarn;

use WebAPI::DBIC::Machine;
use WebAPI::HTTP::Throwable::Factory;

# pre-load some modules to improve shared memory footprint
require DBIx::Class::SQLMaker;
require DBIx::Class::Storage::DBI::Pg;

use Moo;
use namespace::clean;

$ENV{PLACK_ENV} ||= 'production';
my $in_production = ($ENV{PLACK_ENV} eq 'production');

has schema => (is => 'ro', required => 1);
has opt_writable => (is => 'ro', default => 1);
has extra_routes => (is => 'ro', lazy => 1, builder => 1);
has auto_routes => (is => 'ro', lazy => 1, builder => 1);

sub _build_extra_routes { [] }
sub _build_auto_routes {
    my ($self) = @_;

    my @routes;
    my %source_names = map { $_ => 1 } $self->schema->sources;
    for my $source_names ($self->schema->sources) {
        my $result_source = $self->schema->source($source_names);
        next unless $result_source->name =~ /^[\w\.]+$/x;
        #my %relationships;
        for my $rel_name ($result_source->relationships) {
            my $rel = $result_source->relationship_info($rel_name);
        }
        push @routes, [
            $result_source->name => $result_source->source_name
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
                $attr{templated} = JSON::true;
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

    warn sprintf "/%s => %s (%s)\n", $path, $resultset, $rs->result_class;

    # XXX might want to distinguish writable from non-writable (read-only) methods
    my $invokeable_on_set  = delete $opts{invokeable_on_set}  || [];
    my $invokeable_on_item = delete $opts{invokeable_on_item} || [];
    # disable all methods if not writable, for safety: (perhaps allow get_* methods)
    $invokeable_on_set  = undef unless $self->opt_writable;
    $invokeable_on_item = undef unless $self->opt_writable;

    # regex to validate the id
    # XXX could check the data types of the PK fields, or simply remove this
    # validation and let the resource handle whatever value comes
    my $qr_id = qr/^-?\d+$/, # int, but allow for -1 etc

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
        return sub {
            my $req = shift;
            my $args = shift;
            $args->{set} = $rs; # closes over $rs above
            $args->{$_} = shift for @params; # in path param name order
        }
    };
    my @routes;

    push @routes, "$path" => { # set (aka collection)
        resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->(),
    };

    push @routes, "$path/invoke/:method" => { # method call on set
        validations => { method => $qr_names->(@$invokeable_on_set) },
        resource => 'WebAPI::DBIC::Resource::GenericSetInvoke',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->('method'),
    } if @$invokeable_on_set;

    push @routes, "$path/:id" => { # item
        validations => { id => $qr_id },
        resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->('id'),
    };

    push @routes, "$path/:id/invoke/:method" => { # method call on item
        validations => {
            id => $qr_id,
            method => $qr_names->(@$invokeable_on_item),
        },
        resource => 'WebAPI::DBIC::Resource::GenericItemInvoke',
        route_defaults => $route_defaults,
        getargs => $mk_getargs->('id', 'method'),
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

    my @routes = $self->all_routes;

    my $router = Path::Router->new;
    while (my $r = shift @routes) {
        my $spec = shift @routes or confess "panic";

        my $getargs = $spec->{getargs};
        my $resource_class = $spec->{resource} or confess "panic";
        load $resource_class;

        $router->add_route($r,
            validations => $spec->{validations} || {},
            defaults => $spec->{route_defaults},
            target => sub {
                my $request = shift; # url args remain in @_

                #local $SIG{__DIE__} = \&Carp::confess;

                my %resource_args = (
                    writable => $self->opt_writable,
                    throwable => 'WebAPI::HTTP::Throwable::Factory',
                );
                # perform any required setup for this request & params in @_
                $getargs->($request, \%resource_args, @_) if $getargs;

                warn "Running machine for $resource_class (with @{[ keys %resource_args ]})\n"
                    if $ENV{PLACK_ENV} eq 'development';
                my $app = WebAPI::DBIC::Machine->new(
                    resource => $resource_class,
                    debris   => \%resource_args,
                    tracing => !$in_production,
                )->to_app;
                my $resp = eval { $app->($request->env) };
                #Dwarn $resp;
                if ($@) { # XXX report and rethrow
                    Dwarn [ "EXCEPTION from app: $@" ];
                    die; ## no critic (ErrorHandling::RequireCarping)
                }
                return $resp;
            },
        );
    }

    $router->add_route('', target => \&hal_browser_app);

    Plack::App::Path::Router->new( router => $router )->to_app; # return Plack app
}

1;
__END__
