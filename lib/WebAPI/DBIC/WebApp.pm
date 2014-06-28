#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

use strict;
use warnings;

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 0;
    $ENV{DBI_TRACE} ||= 0;
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
    $|++;
}

use Plack::App::Path::Router;
use HTTP::Throwable::Factory;
use Path::Class::File;
use Path::Router;
use Module::Load;
use Carp qw(croak confess);
use JSON;

use Devel::Dwarn;

use WebAPI::Schema::Corp;
use WebAPI::DBIC::Machine;

# pre-load some modules to improve shared memory footprint
require DBIx::Class::SQLMaker;
require DBIx::Class::Storage::DBI::Pg;


my $in_production = ($ENV{TL_ENVIRONMENT} eq 'production');

my $opt_writable = 1;


my $schema = WebAPI::Schema::Corp->new_default_connect(
    {},
    # connect to yesterdays snapshot because we make edits to the db
    # XXX should really have a better approach for this!
    "corp",
    #"corp_snapshot_previous",
);


{
    package My::HTTP::Throwable::Factory; ## no critic (ProhibitMultiplePackages)
    use parent 'HTTP::Throwable::Factory';
    use Carp qw(carp cluck);
    use JSON;

    sub extra_roles {
        return (
            'HTTP::Throwable::Role::JSONBody', # remove HTTP::Throwable::Role::TextBody
            'StackTrace::Auto'
        );
    }

    sub throw_bad_request {
        my ($class, $status, %opts) = @_;
        cluck("bad status") unless $status =~ /^4\d\d$/;
        carp("throw_bad_request @_");

        # XXX TODO validations
        my $data = {
            errors => $opts{errors},
        };
        my $json_body = JSON->new->ascii->pretty->encode($data);
        # [ 'Content-Type' => 'application/hal+json' ],
        $class->throw( BadRequest => {
            status_code => $status,
            message => $json_body,
        });
        return; # not reached
    }

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
    my ($path, $resultset, %opts) = @_;

    # XXX might want to distinguish writable from non-writable (read-only) methods
    my $invokeable_on_set  = delete $opts{invokeable_on_set}  || [];
    my $invokeable_on_item = delete $opts{invokeable_on_item} || [];
    # disable all methods if not writable, for safety: (perhaps allow get_* methods)
    $invokeable_on_set  = undef unless $opt_writable;
    $invokeable_on_item = undef unless $opt_writable;

    my $qr_id = qr/^-?\d+$/, # int, but allow for -1 etc
    my $qr_names = sub {
        my $names_r = join "|", map { quotemeta $_ } @_ or confess "panic";
        return qr/^(?:$names_r)$/x;
    };

    my $rs = $schema->resultset($resultset);
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

my @routes;

if (0) { # all!
    my %source_names = map { $_ => 1 } $schema->sources;
    for my $source_names ($schema->sources) {
        my $result_source = $schema->source($source_names);
        next unless $result_source->name =~ /^[\w\.]+$/x;
        #my %relationships;
        for my $rel_name ($result_source->relationships) {
            my $rel = $result_source->relationship_info($rel_name);
        }
        push @routes, mk_generic_dbic_item_set_routes( $result_source->name => $result_source->source_name);
    }
}
else {

    push @routes, mk_generic_dbic_item_set_routes( 'person_types' => 'PersonType');
    push @routes, mk_generic_dbic_item_set_routes( 'persons' => 'People');
    push @routes, mk_generic_dbic_item_set_routes( 'phones' => 'Phone');
    push @routes, mk_generic_dbic_item_set_routes( 'person_emails' => 'Email');
    push @routes, mk_generic_dbic_item_set_routes( 'client_auths' => 'ClientAuth');
    push @routes, mk_generic_dbic_item_set_routes( 'ecosystems' => 'Ecosystem');
    push @routes, mk_generic_dbic_item_set_routes( 'ecosystems_people' => 'EcosystemsPeople',
        invokeable_on_item => [
            'item_instance_description',    # used for testing
            'bulk_transfer_leads',
        ]
    );
    push @routes, mk_generic_dbic_item_set_routes( 'ecosystem_domains' => 'EcosystemDomain');

}


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
                writable => $opt_writable,
                throwable => 'My::HTTP::Throwable::Factory',
            );
            # perform any required setup for this request & params in @_
            $getargs->($request, \%resource_args, @_) if $getargs;

            warn "Running machine for $resource_class (with @{[ keys %resource_args ]})\n"
                if $ENV{TL_ENVIRONMENT} eq 'development';
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
