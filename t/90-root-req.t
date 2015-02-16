#!/usr/bin/env perl

use lib 't/lib';
use TestKit;

fixtures_ok qw/basic/;

subtest '===== basics - specs =====' => sub {
    my ($self) = @_;

    my $app = TestWebApp->new({
        routes => [ map( Schema->source($_), Schema->sources) ]
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

done_testing();

__DATA__
Config:
Accept: text/html

Name: get root url as html
GET /

Config:
Accept: application/vnd.wapid+json

Name: get root url as plain json
GET /
