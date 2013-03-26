
use tlcomp 'clients_dataservice';

use Plack::Builder;
use Plack::App::File;

use Devel::Dwarn;

my $app = require WebAPI::DBIC::WebApp;

builder {
    enable 'SimpleLogger';  # show on STDERR
    #enable "Plack::Middleware::AccessLog", format => '%h %l %u %t "%r" %>s %b %{X-Runtime}o';
    enable "Runtime", header_name => "X-Runtime";
    enable "HTTPExceptions", rethrow => 1;
    #enable "StackTrace", force => 1;

    #enable sub { my $app=shift; sub { Dwarn my $env=shift; my $res = $app->($env); return $res; }; };

    mount "/clients/v1/" => builder {
        mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
        mount "/" => $app;
    };

    # root redirect for discovery
    mount "/" => sub { [ 302, [ Location => "/clients/v1/" ], [ ] ] };
};
