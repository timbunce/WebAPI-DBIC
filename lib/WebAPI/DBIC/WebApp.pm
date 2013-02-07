#!/usr/bin/env perl

package WebAPI::DBIC::WebApp;

BEGIN {
        $ENV{WM_DEBUG} = 0;
        $ENV{DBIC_TRACE} = 1;
        $ENV{DBI_TRACE} = 0;
        $ENV{PATH_ROUTER_DEBUG} = 0;
 }

#use 5.16.0;
use Web::Simple;
use Plack::App::Path::Router;
use Devel::Dwarn;
use Path::Class::File;
use Path::Router;
use Module::Load;

use WebAPI::Schema::Corp;
use WebAPI::DBIC::Machine;

my $schema = WebAPI::Schema::Corp->new_default_connect(
    {},
    # connect to yesterdays snapshot because we make edits to the db
    # XXX should really have a better approach for this!
    "corp_snapshot_previous"
);

sub wm {
   load $_[0];
   WebAPI::DBIC::Machine->new(
      resource => $_[0],
      debris   => $_[1],
      tracing => 0,
   )->to_app;
}

my $router = Path::Router->new;

$router->add_route('/person_types' =>
    target => sub {
        my ($request) = @_;
        my $set = $schema->resultset('PersonType');
        my $app = wm('WebAPI::DBIC::Resource::PersonTypes', { set => $set, writable => 1, });
        $app->($request->env);
    }
);

$router->add_route('/person_types/:id' => (
    validations => {
        id => qr/^\d+$/,
    },
    target => sub {
        my ($request, $id) = @_;
        my $set = $schema->resultset('PersonType');
        my $app = wm('WebAPI::DBIC::Resource::PersonType', { item => $set->find($id), writable => 1, });
        $app->($request->env);
    }
));

Plack::App::Path::Router->new( router => $router );
