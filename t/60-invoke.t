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
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/item_instance_description", [], {
        args => []
    }));
    my $data = dsresp_ok($res);
    is_deeply $data, { result => "Ecosystems People(id=1)" }, 'returns expected data'
        or diag $data;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/item_instance_description", [], {
        args => {}
    }));
    dsresp_ok($res, 400);
    like $res->content, qr/args must be an array/i;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/item_instance_description", [], {
        nonesuch => 1
    }));
    dsresp_ok($res, 400);
    like $res->content, qr/Unknown attributes: nonesuch/i;
};

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/item_instance_description", [], []));
    dsresp_ok($res, 400);
    like $res->content, qr/not a JSON hash/i;
};


test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/ecosystems_people/1/invoke/bulk_transfer_leads", [], {
        args => [ assigner_id => 'nonesuch' ] # invalid integer param
    }));
    dsresp_ok($res, 400);
    like $res->content, qr/The 'assigner_id' parameter/i;
};

done_testing;
