
use tlcomp 'clients_dataservice';

use Plack::Builder;
use Plack::App::File;

my $app = require WebAPI::DBIC::WebApp;

builder {
    enable 'SimpleLogger';  # show on STDERR
    enable "Plack::Middleware::AccessLog",
        format => '%h %l %u %t "%r" %>s %b %{X-Runtime}o';
    enable "Runtime", header_name => "X-Runtime";
    #enable "StackTrace", force => 1;
    enable "HTTPExceptions", rethrow => 1;
    mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
    mount "/" => $app;
};
