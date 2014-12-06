#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

subtest "===== Paging =====" => sub {
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

Name: get 1 row
GET /artist?rows=1

Name: get 2 rows with count
GET /artist?rows=2&with=count

Name: get 2 rows from second 'page'
GET /artist?rows=2&page=2

