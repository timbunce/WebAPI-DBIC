
use lib 't/lib';

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 0;
    $ENV{DBI_TRACE} ||= 0;
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
    $ENV{WEBAPI_DBIC_DEBUG} ||= 0;
    $|++;
}

use DummyLoadedSchema;
use Plack::Builder;
use Plack::App::File;
use WebAPI::DBIC::WebApp;

use Alien::Web::HalBrowser;

my $hal_app = Plack::App::File->new(
  root => Alien::Web::HalBrowser->dir
)->to_app;

use Devel::Dwarn;

my $app = WebAPI::DBIC::WebApp->new({
    schema => DummyLoadedSchema->connect,
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
        mount "/browser" => $hal_app;
        mount "/" => $app;
    };

    # root redirect for discovery - redirect to API
    mount "/" => sub { [ 302, [ Location => "$app_prefix/" ], [ ] ] };
};
