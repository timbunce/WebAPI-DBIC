
use tlcomp 'clients_dataservice';

use Plack::Builder;
use Plack::App::File;

my $app = require WebAPI::DBIC::WebApp;

builder {
    enable 'SimpleLogger';  # show on STDERR
    mount "/browser" => Plack::App::File->new(root => "hal-browser")->to_app;
    mount "/" => $app;
};
