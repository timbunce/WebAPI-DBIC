#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 1;
    $ENV{DBI_TRACE} ||= 0;
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
}

use Web::Simple;
use Plack::App::Path::Router;
use HTTP::Throwable::Factory;
use Path::Class::File;
use Path::Router;
use Module::Load;
use Carp;
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



sub throw_bad_request {
    my ($status, %opts) = @_;
    cluck("bad status") unless $status =~ /^4\d\d$/;

    # XXX TODO validations
    my $data = {
        errors => $opts{errors},
    };
    my $json_body = JSON->new->ascii->pretty->encode($data);
warn "throw_bad_request $json_body";
    # [ 'Content-Type' => 'application/hal+json' ],
    HTTP::Throwable::Factory->throw({
        status_code => $status,
        reason => 'Bad request',
        text_body => $json_body,
    });
}


sub _handle_prefetch_param {
    my ($rs, $args, $prefetch_param) = @_;

    if (my @prefetch = split(',', $prefetch_param||"")) {
        my $result_class = $rs->result_class;
        for my $prefetch (@prefetch) {
            my $rel = $result_class->relationship_info($prefetch);

            # limit to simple single relationships, e.g., belongs_to
            throw_bad_request(400, errors => [{
                        $prefetch => "not a valid relationship",
                        _meta => {
                            relationship => $rel,
                            relationships => [ $result_class->relationships ]
                        }, # XXX
                    }])
                unless $rel
                    and $rel->{attrs}{accessor} eq 'single'       # sanity
                    and $rel->{attrs}{is_foreign_key_constraint}; # safety/speed

            # XXX hack?: perhaps use {embedded}{$key} = sub { ... };
            # see lib/WebAPI/DBIC/Resource/Role/DBIC.pm
            $args->{prefetch}{$prefetch} = { key => $prefetch };
        }

        $rs = $rs->search_rs(undef, { prefetch => \@prefetch, });
    }

    return $rs;
}

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
            getargs => sub {
                my ($request, $rs, $id) = @_;
                my %args;

                $rs = _handle_prefetch_param($rs, \%args, $request->param('prefetch'))
                    if $request->param('prefetch');

                $args{item} = $rs->find($id);
                return \%args;
            },
            resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
        },

        # set (aka collection)
        "$path" => {
            resultset => $rs->search_rs(undef, {
                # XXX default attributes (see also getargs below)
                order_by => { -asc => [ map { "me.$_" } $rs->result_source->primary_columns ] },
            }),
            getargs => sub {
                my ($request, $rs, $id) = @_;
                my %args;

                # XXX TODO add params hashref to debris, load from query params with validation and defaults

                $rs = $rs->page($request->param('page') || 1);
                # XXX this breaks encapsulation but seems safe enough just after page() above
                $rs->{attrs}{rows} = $request->param('rows') || 100;

                $rs = _handle_prefetch_param($rs, \%args, $request->param('prefetch'))
                    if $request->param('prefetch');

                my @errors;
                for my $param (keys %{ $request->parameters }) {
                    my $val = $request->param($param);

                    # parameter names with a ~json suffix have JSON encoded values
                    my $is_json = ($param =~ s/~json$//);
                    $val = JSON->new->allow_nonref->decode($val) if $is_json;

                    if ($param =~ /^me\.(\w+)$/) {
                        $rs = $rs->search_rs({ $1 => $val });
                    }
                    elsif ($param eq 'page' or $param eq 'rows' or $param eq 'prefetch') {
                        # handled above
                    }
                    elsif ($param eq 'with') { # XXX with=count - generalize
                        my ($field, $is_json) = ($1, $2);
                        my $val = $request->param($param);
                    }
                    elsif ($param eq 'order') {
                        # we take care to avoid injection risks
                        my @order_spec;
                        for my $clause (split /\s*,\s*/, $val) {
                            my ($field, $dir) = ($clause =~ /^([a-z0-9\.]*)\b(?:\s+(asc|desc))?\s*$/i);
                            unless (defined $field) {
                                push @errors, { $param => "invalid order clause" };
                                next;
                            }
                            $dir ||= 'asc';
                            push @order_spec, { "-$dir" => $field };
                        }
                        $rs = $rs->search_rs(undef, { order_by => \@order_spec });
                    }
                    else {
                        push @errors, { $param => "unknown parameter" };
                    }
                }
                # XXX abstract out the creation of error responses
                throw_bad_request(400, errors => \@errors)
                    if @errors;

                $args{set} = $rs;
                return \%args;
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

            warn "Running machine for $resource_class (with @{[ keys %$args ]})\n";
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
