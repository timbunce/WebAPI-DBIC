#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

subtest "===== Paging =====" => sub {
    my ($self) = @_;

    my $app = TestWebApp->new({
        routes => [ map( Schema->source($_), 'Artist') ]
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

done_testing();

__DATA__
Config:
Accept: application/vnd.wapid+json

Name: get 1 row
GET /artist?rows=1

Name: get 2 rows
GET /artist?rows=2

Name: get 2 rows from second 'page'
GET /artist?rows=2&page=2

