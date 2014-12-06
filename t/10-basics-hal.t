#!/usr/bin/env perl


use lib 't/lib';
use TestKit;

fixtures_ok [qw/basic/];

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
Accept: application/hal+json,application/json

Name: get single item
GET /artist/1

Name: get different single item
GET /artist/2

Name: get set of items
GET /artist

Name: get item with multi-field key
GET /gig/1/2014-01-01T01:01:01Z

Name: get different item with multi-field key
GET /gig/2/2014-06-30T19:00:00Z

Name: get view data
GET /classic_albums
