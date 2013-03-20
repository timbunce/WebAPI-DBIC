#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 1;
    $ENV{DBI_TRACE} ||= 0 || ($ENV{TL_ENVIRONMENT} eq 'staging' ? 1 : 0);
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
    $|++;
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

{
    package My::HTTP::Throwable::Factory;
    use parent 'HTTP::Throwable::Factory';
    use Carp qw(cluck);
    use JSON;

    sub extra_roles {
        'HTTP::Throwable::Role::JSONBody', # remove HTTP::Throwable::Role::TextBody
        'StackTrace::Auto',
    }

    sub throw_bad_request {
        my ($class, $status, %opts) = @_;
        cluck("bad status") unless $status =~ /^4\d\d$/;
        cluck("throw_bad_request @_");

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
    }

}




sub mk_generic_dbic_item_set_routes {
    my ($path, $resultset) = @_;
    my @routes;

    my $rs = $schema->resultset($resultset);

    push @routes, "$path" => { # set (aka collection)

        resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',

        resultset => $rs,

        getargs => sub {
            my ($request, $_rs, $id) = @_;
            my $args = { set => $_rs };

            # XXX TODO add params hashref to debris, load from query params with validation and defaults

            $args->{set} = $args->{set}->page($request->param('page') || 1);
            # XXX this breaks encapsulation but seems safe enough just after page() above
            $args->{set}->{attrs}{rows} = $request->param('rows') || 30;

            # normalize params, eg handle ~json
            my %params;
            for my $param (keys %{ $request->parameters }) {
                my $val = $request->param($param);

                # parameter names with a ~json suffix have JSON encoded values
                my $is_json = ($param =~ s/~json$//);
                $val = JSON->new->allow_nonref->decode($val) if $is_json;

                $params{$param} = $val;
            }

            my @errors;
            for my $param (keys %params) {
                my $val = $params{$param};

                if ($param =~ /^me\.\w+(?:\.\w+)*$/) {
                    # we use me.relation.field=... to refer to relations via this param
                    # so the param can be recognized by the leading 'me.'
                    # but we strip off the leading 'me.' if there's a me.foo.bar
                    $param =~ s/^me\.// if $param =~ m/^me\.\w+\.\w+/;
                    $args->{set} = $args->{set}->search_rs({ $param => $val });
                }
                elsif ($param eq 'distinct') {
                    $args->{set} = $args->{set}->search_rs(undef, { distinct => $val });
                    # these restrictions avoid edge cases we don't want to deal with yet
                    push @errors, "distinct param requires order param"
                        unless $params{order};
                    push @errors, "distinct param requires fields param"
                        unless $params{fields};
                    push @errors, "distinct param requires fields and orders params to have same value"
                        unless $params{fields} eq $params{order};
                }
                elsif ($param eq 'prefetch') {
                }
                elsif ($param eq 'order') {
                }
                elsif ($param eq 'fields') {
                }
                elsif ($param eq 'page' or $param eq 'rows') {
                    # handled above
                }
                elsif ($param eq 'with') { # XXX with=count - generalize
                    # handled in lib/WebAPI/DBIC/Resource/Role/DBIC.pm
                }
                elsif ($param eq 'rollback') {
                    # handled in lib/WebAPI/DBIC/Resource/Role/Set.pm currently
                }
                else {
                    push @errors, { $param => "unknown parameter" };
                }
            }
            # XXX abstract out the creation of error responses
            My::HTTP::Throwable::Factory->throw_bad_request(400, errors => \@errors)
                if @errors;

            # set a default order-by if one hasn't been specified
            $args->{set} = $args->{set}->search_rs(undef, {
                order_by => { -asc => [ map { "me.$_" } $rs->result_source->primary_columns ] },
            }) if not $args->{set}->is_ordered
                  and $args->{set}->is_paged;

            return $args;
        },
    };

    push @routes, "$path/:id" => { # item
        validations => { id => qr/^\d+$/ },
        resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
        resultset => $rs,
        getargs => sub {
            my ($request, $rs, $id) = @_;
            my %args = (set => $rs);

            #_handle_prefetch_param(\%args, $request->param('prefetch')) if $request->param('prefetch');
            #_handle_fields_param(\%args, $request->param('fields')) if $request->param('fields');

            #$args{item} = $args{set}->find($id);
            $args{id} = $id;
            return \%args;
        },
        resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
    };

    return @routes;
}

my @routes;

if (0) { # all!
    my %source_names = map { $_ => 1 } $schema->sources;
    for my $source_names ($schema->sources) {
        my $result_source = $schema->source($source_names);
        next unless $result_source->name =~ /^[\w\.]+$/;
        my %relationships;
        for my $rel_name ($result_source->relationships) {
            my $rel = $result_source->relationship_info($rel_name);
        }
        #push @routes, mk_generic_dbic_item_set_routes( $result_source->name => $result_source->source_name);
    }
}
else {

    push @routes, mk_generic_dbic_item_set_routes( 'person_types' => 'PersonType');
    push @routes, mk_generic_dbic_item_set_routes( 'persons' => 'People');
    push @routes, mk_generic_dbic_item_set_routes( 'phones' => 'Phone');
    push @routes, mk_generic_dbic_item_set_routes( 'person_emails' => 'Email');
    push @routes, mk_generic_dbic_item_set_routes( 'client_auths' => 'ClientAuth');
    push @routes, mk_generic_dbic_item_set_routes( 'ecosystems' => 'Ecosystem');
    push @routes, mk_generic_dbic_item_set_routes( 'ecosystems_people' => 'EcosystemsPeople');

}


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
        defaults => {
            _rs => $rs,
            result_class => $rs->result_class,
            _title => $rs->result_class,
        },
        target => sub {
            my $request = shift; # url args remain in @_

#warn "$r: args @{[%$args]}";
#$DB::single=1;
local $SIG{__DIE__} = \&Carp::confess;

            # perform any required setup for this request
            # bail-out if a Plack::Response is given, eg an error
            my $args = $getargs ? $getargs->($request, $rs, @_) : {};
            return $args if UNIVERSAL::can($args, 'finalize');

            warn "Running machine for $resource_class (with @{[ keys %$args ]})\n"
                if $ENV{TL_ENVIRONMENT} eq 'development';
            my $app = WebAPI::DBIC::Machine->new(
                resource => $resource_class,
                debris   => {
                    set => $rs,
                    writable => $writable,
                    throwable => 'My::HTTP::Throwable::Factory',
                    %$args
                },
                tracing => !$in_production,
            )->to_app;
            my $resp = eval { $app->($request->env) };
            #Dwarn $resp;
            if ($@) { Dwarn [ "EXCEPTION from app: $@" ]; die $@ } # report and rethrow
            return $resp;
        },
    );
};

if (1) { # root level links to describe/explore the api (eg for the hal-browser)
    my %links = (self => { href => "/" } );

    my @resource_links;
    foreach my $route (@{$router->routes})  {
        my @parts;
        my %attr = ( title => $route->defaults->{_title}||"" );
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

Plack::App::Path::Router->new( router => $router )->to_app; # return Plack app
