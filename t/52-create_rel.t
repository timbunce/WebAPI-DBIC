#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

use lib "t";
use TestDS;

my $test_key_string = "clients_dataservice";

my $app = require 'clients_dsapi.psgi'; # WebAPI::DBIC::WebApp;

note "===== Create - POST =====";

my $item;

test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/persons?rollback=1&prefetch=self", [], {
        full_name => "foo",
        deleted_at => "2000-01-01",
        _embedded => {
            type => {
                name => "test",
                description => "test",
            }
        }
    }));
    my ($location, $data) = dsresp_created_ok($res);
};

done_testing();
