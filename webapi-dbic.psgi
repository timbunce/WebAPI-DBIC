
use lib 't/lib';

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 0;
    $ENV{DBI_TRACE} ||= 0;
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
    $ENV{WEBAPI_DBIC_DEBUG} ||= 0;
    $|++;
}

use DummySchema;
use Plack::Builder;
use Plack::App::File;
use WebAPI::DBIC::WebApp;

use Devel::Dwarn;

my $dummy = DummySchema->new;
$dummy->load_fixtures('basic');
my $schema = $dummy->schema;

my $app = WebAPI::DBIC::WebApp->new({
    schema => $schema,
})->to_psgi_app;

my $app_prefix = "/clients/v1";

builder {
    enable 'SimpleLogger';  # show on STDERR
    #enable "Plack::Middleware::AccessLog", format => '%h %l %u %t "%r" %>s %b %{X-Runtime}o';
    enable "Runtime", header_name => "X-Runtime";
    enable "HTTPExceptions", rethrow => 1;
    #enable "StackTrace", force => 1;

    #enable sub { my $app=shift; sub { Dwarn my $env=shift; my $res = $app->($env); return $res; }; };

    mount "$app_prefix/" => builder {
        mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
        mount "/" => $app;
    };

    # root redirect for discovery - redirect to API
    mount "/" => sub { [ 302, [ Location => "$app_prefix/" ], [ ] ] };
};
