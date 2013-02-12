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

use Devel::Dwarn;

use WebAPI::Schema::Corp;
use WebAPI::DBIC::Machine;

my $opt_writable = 1;

my $schema = WebAPI::Schema::Corp->new_default_connect(
    {},
    # connect to yesterdays snapshot because we make edits to the db
    # XXX should really have a better approach for this!
    "corp_snapshot_previous"
);


my $getargs_id_item = sub { my ($request, $rs, $id) = @_; return { item => $rs->find($id) } };

my @routes = (
    '/person_types' => {
        resultset => 'PersonType',
        resource => 'WebAPI::DBIC::Resource::GenericSetDBIC',
    },

    '/person_types/:id' => {
        validations => { id => qr/^\d+$/ },
        resultset => 'PersonType',
        resource => 'WebAPI::DBIC::Resource::GenericItemDBIC',
        getargs => $getargs_id_item,
    }
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

Plack::App::Path::Router->new( router => $router );
