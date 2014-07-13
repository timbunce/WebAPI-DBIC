#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

use lib "t";
use TestDS;

my $test_key_string = "clients_dataservice";

my $app = require WebAPI::DBIC::WebApp;

note "===== Invoke =====";

my $item;

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/table", [], {
        args => []
    }));
    my $data = dsresp_ok($res);
    is_deeply $data, { result => "ecosystems_people" }, 'returns expected data'
        or diag $data;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/table", [], {
        args => {}
    }));
    dsresp_ok($res, 400);
    like $res->content, qr/args must be an array/i;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/table", [], {
        nonesuch => 1
    }));
    dsresp_ok($res, 400);
    like $res->content, qr/Unknown attributes: nonesuch/i;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/table", [], []));
    dsresp_ok($res, 400);
    like $res->content, qr/not a JSON hash/i;
};

done_testing;
