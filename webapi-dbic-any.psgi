=head1 NAME

webapi-dbic-any.psgi - instant WebAPI::DBIC browser for any DBIx::Class schema

=head1 SYNOPSIS

    $ export WEBAPI_DBIC_SCHEMA=Foo::Bar     # your own schema
    $ export WEBAPI_DBIC_HTTP_AUTH_TYPE=none # recommended
    $ export DBI_DSN=dbi:Driver:...          # your own database
    $ export DBI_USER=... # for initial connection, if needed
    $ export DBI_PASS=... # for initial connection, if needed
    $ plackup webapi-dbic-any.psgi
    ... open a web browser on port 5000 to browse your new API

The API provided by this .psgi file will be read-only unless the
C<WEBAPI_DBIC_WRITABLE> env var is true.

For details on the C<WEBAPI_DBIC_HTTP_AUTH_TYPE> env var and security issues
see C<http_auth_type> in L<WebAPI::DBIC::Resource::Role::DBICAuth>.

=cut

use strict;
use warnings;

use Plack::Builder;
use Plack::App::File;
use WebAPI::DBIC::WebApp;
use Alien::Web::HalBrowser;

my $hal_app = Plack::App::File->new(
  root => Alien::Web::HalBrowser->dir
)->to_app;

my $schema_class = $ENV{WEBAPI_DBIC_SCHEMA}
    or die "WEBAPI_DBIC_SCHEMA env var not set";
eval "require $schema_class" or die "Error loading $schema_class: $@";

my $schema = $schema_class->connect(); # uses DBI_DSN, DBI_USER, DBI_PASS env vars

my $app = WebAPI::DBIC::WebApp->new({
    schema   => $schema,
    writable => $ENV{WEBAPI_DBIC_WRITABLE}, # read-only if not set
    http_auth_type => $ENV{WEBAPI_DBIC_HTTP_AUTH_TYPE} || 'Basic', # Basic is insecure
})->to_psgi_app;

my $app_prefix = "/webapi-dbic";

builder {
    enable "SimpleLogger";  # show on STDERR

    mount "$app_prefix/" => builder {
        mount "/browser" => $hal_app;
        mount "/" => $app;
    };

    # root redirect for discovery - redirect to API
    mount "/" => sub { [ 302, [ Location => "$app_prefix/" ], [ ] ] };
};
