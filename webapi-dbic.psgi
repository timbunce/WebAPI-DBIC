
use Dummy::Schema;
use Plack::Builder;
use Plack::App::File;
use WebAPI::DBIC::WebApp;

use Devel::Dwarn;

BEGIN {
    $ENV{WM_DEBUG} ||= 0; # verbose
    $ENV{DBIC_TRACE} ||= 0;
    $ENV{DBI_TRACE} ||= 0;
    $ENV{PATH_ROUTER_DEBUG} ||= 0;
    $|++;
}

my $schema = DummySchema->new_default_connect( {}, "corp" );
my $app = WebAPI::DBIC::WebApp->new({
    schema => $schema,
    extra_routes => [
        [ 'person_types'      => 'PersonType' ],
        [ 'persons'           => 'People' ],
        [ 'phones'            => 'Phone' ],
        [ 'person_emails'     => 'Email' ],
        [ 'client_auths'      => 'ClientAuth' ],
        [ 'ecosystems'        => 'Ecosystem' ],
        [ 'ecosystems_people' => 'EcosystemsPeople',
            invokeable_on_item => [
                'item_instance_description',    # used for testing
                'bulk_transfer_leads',
            ]
        ],
        [ 'ecosystem_domains' => 'EcosystemDomain' ],
    ],
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
