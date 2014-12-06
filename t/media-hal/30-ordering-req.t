#!/usr/bin/env perl

use lib "t/lib";
use TestKit;
use Sort::Key qw/multikeysorter/;

fixtures_ok [qw/basic/];


subtest "===== Ordering =====" => sub {
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

Name: order by PK asc
GET /cd?order=me.cdid

Name: order by PK desc
GET /cd?order=me.cdid%20desc

Name: order by year desc and title desc
GET /cd?sort=me.year%20desc,title%20desc

Name: order by field in a relation (and the primary set for test stability)
# might change later to: sort[artist]=name&sort[cd]=cdid
GET /cd?prefetch=artist&sort=artist.name,cdid

Name: order by field in two relations
GET /cd?prefetch=artist,genre&order=-genre.name,artist.name
