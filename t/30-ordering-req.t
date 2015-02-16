#!/usr/bin/env perl


use lib "t/lib";
use TestKit;
use Sort::Key qw/multikeysorter/;

fixtures_ok [qw/basic/];


subtest "===== Ordering =====" => sub {
    my ($self) = @_;

    my $app = TestWebApp->new({
        routes => [ map( Schema->source($_), 'CD') ]
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

done_testing();

__DATA__
Config:
Accept: application/vnd.wapid+json

Name: order by PK asc
GET /cd?order=me.cdid

Name: order by PK desc
GET /cd?order=me.cdid%20desc&fields=cdid,year

Name: order by year desc and title desc
GET /cd?sort=me.year%20desc,title%20desc&fields=cdid,year,title

Name: order by year desc and title desc using JSON API style
GET /cd?sort=-year,-title&fields=cdid,year,title
