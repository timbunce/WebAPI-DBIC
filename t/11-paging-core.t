#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::DBIx::Class;
fixtures_ok qw/basic/;

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

Name: get 1 row
GET /artist?rows=1

Name: get 2 rows
GET /artist?rows=2

Name: get 2 rows from second 'page'
GET /artist?rows=2&page=2

