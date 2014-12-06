#!/usr/bin/env perl

use lib 't/lib';
use TestKit;

fixtures_ok qw/basic/;

subtest '===== basics - specs =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
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
Accept: application/json

Name: get root url as plain json
GET /
