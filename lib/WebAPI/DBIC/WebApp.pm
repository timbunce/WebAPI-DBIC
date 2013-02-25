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


my $in_production = ($ENV{TL_ENVIRONMENT} eq 'production');

my $opt_writable = 1;


my $schema = WebAPI::Schema::Corp->new_default_connect(
    {},
    # connect to yesterdays snapshot because we make edits to the db
    # XXX should really have a better approach for this!
    "corp",
    #"corp_snapshot_previous",
);


=head2 Common Parameters for Collection Resources

=head3 page_size

=head3 page

=head me.*

=cut


sub mk_generic_dbic_item_set_route_pair {
    my ($path, $resultset) = @_;

    my $rs = $schema->resultset($resultset);
    return (

        # item
        "$path/:id" => {
            validations => { id => qr/^\d+$/ },
            resultset => $rs,
            getargs => sub { my ($request, $rs, $id) = @_; return { item => $rs->find($id) } },
            resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
        },

        # set (aka collection)
        "$path" => {
            resultset => $rs->search_rs(undef, {
                # XXX default attributes (see also getargs below)
                order_by => { -asc => [ $rs->result_source->primary_columns ] },
            }),
            getargs => sub {
                my ($request, $rs, $id) = @_;

                $rs = $rs->page($request->param('page') || 1);
                # XXX this breaks encapsulation but seems safe enough just after page() above
                $rs->{attrs}{rows} = $request->param('rows') || 100;

                my @errors;
                for my $param (keys %{ $request->parameters }) {
                    if ($param =~ /^me\.(\w+)(~json)?$/) {
                        my ($field, $is_json) = ($1, $2);
                        my $val = $request->param($param);
                        # parameters with a ~json suffix are JSON encoded
                        $val = JSON->new->allow_nonref->decode($val) if $is_json;
                        $rs = $rs->search_rs({ $field => $val });
                    }
                    elsif ($param eq 'page' or $param eq 'rows') {
                        # handled above
                    }
                    else {
                        push @errors, { $param => "unknown parameter" };
                    }
                }
                # XXX abstract out the creation of error responses
                return Plack::Response->new(400, [ 'Content-Type' => 'application/hal+json' ], JSON->new->ascii->pretty->encode(\@errors))
                    if @errors;

                return { set => $rs }
            },
            resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        },

    );
}

my @routes;
push @routes, mk_generic_dbic_item_set_route_pair( 'person_types' => 'PersonType');
push @routes, mk_generic_dbic_item_set_route_pair( 'persons' => 'People');
push @routes, mk_generic_dbic_item_set_route_pair( 'person_emails' => 'Email');
push @routes, mk_generic_dbic_item_set_route_pair( 'client_auths' => 'ClientAuth');
push @routes, mk_generic_dbic_item_set_route_pair( 'ecosystems' => 'Ecosystem');
push @routes, mk_generic_dbic_item_set_route_pair( 'ecosystems_people' => 'EcosystemsPeople');


my $router = Path::Router->new;
while (my $r = shift @routes) {
    my $spec = shift @routes or die "panic";

    my $rs = $spec->{resultset};
    my $getargs = $spec->{getargs};
    my $writable = (exists $spec->{writable}) ? $spec->{writable} : $opt_writable;
    my $resource_class = $spec->{resource} or die "panic";
    load $resource_class;

    $router->add_route($r,
        validations => $spec->{validations} || {},
        defaults => { _rs => $rs },
        target => sub {
            my $request = shift; # url args remain in @_

#warn "$r: args @{[%$args]}";
#$DB::single=1;
#local $SIG{__DIE__} = \&Carp::confess;

            # perform any required setup for this request
            # bail-out if a Plack::Response is given, eg an error
            my $args = $getargs ? $getargs->($request, $rs, @_) : {};
            return $args if UNIVERSAL::can($args, 'finalize');

            my $app = WebAPI::DBIC::Machine->new(
                resource => $resource_class,
                debris   => {
                    set => $rs,
                    writable => $writable,
                    %$args
                },
                tracing => !$in_production,
            )->to_app;
            my $resp = $app->($request->env);
            #Dwarn $resp;
            return $resp;
        },
    );
};

if (1) { # root level links to describe/explore the api (eg for the hal-browser)
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
                $attr{title} =~ s/ set$/ item/; # XXX hack

            } else {
                push @parts, "/$c";
                (my $result_class = $route->defaults->{_rs}->result_class) =~ s/.*Result:://;
                #my $result_class = 'x';
                $attr{title} .= "$result_class set"; # XXX hack
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
            # if the request for the root url is from a browser
            # then redirect to the HAL browser interface
            # (XXX should probably be done in our .psgi file)
            return [ 302, [ Location => "/browser/hal_browser.html" ], [ ] ]
                if $request->headers->header('Accept') =~ /html/;
            return [ 200, [ 'Content-Type' => 'application/json' ],
                [ JSON->new->ascii->pretty->encode($root_data) ]
            ]
        },
    );
}

Plack::App::Path::Router->new( router => $router ); # return Plack app
