=head1 NAME

webapi-dbic-any.psgi - instance WebAPI::DBIC browser for any DBIx::Class schema

=head1 SYNOPSIS

    $ export WEBAPI_DBIC_SCHEMA=Foo::Bar
    $ export WEBAPI_DBIC_WRITABLE=1 # optional
    $ export DBI_DSN=dbi:Driver:...
    $ export DBI_USER=... # optional, for initial connection
    $ export DBI_PASS=... # optional, for initial connection
    $ plackup webapi-dbic-any.psgi
    ... open a web browser on port 5000 to browse your new API

You'll be asked to authenticate when you start exploring.
Enter any username and password for now - auth is currently disabled
so the DBI_USER/DBI_PASS credentials will be used. XXX

Note that only Basic Authentication is supported at the moment so the
credentials entered via the browser will be sent in clear text over the network.

=cut

use strict;
use warnings;

use Plack::Builder;
use Plack::App::File;
use WebAPI::DBIC::WebApp;

my $schema_class = $ENV{WEBAPI_DBIC_SCHEMA}
    or die "WEBAPI_DBIC_SCHEMA env var not set";
eval "require $schema_class" or die "Error loading $schema_class: $@";

my $schema = $schema_class->connect(); # uses DBI_DSN, DBI_USER, DBI_PASS env vars

my $app = WebAPI::DBIC::WebApp->new({
    schema   => $schema,
    writable => $ENV{WEBAPI_DBIC_WRITABLE}, # read-only if not set
})->to_psgi_app;

my $app_prefix = "/webapi-dbic";

builder {
    enable "SimpleLogger";  # show on STDERR

    mount "$app_prefix/" => builder {
        mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
        mount "/" => $app;
    };

    # root redirect for discovery - redirect to API
    mount "/" => sub { [ 302, [ Location => "$app_prefix/" ], [ ] ] };
};
