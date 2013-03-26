#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

use lib "t";
use TestDS;


my $app = require WebAPI::DBIC::WebApp;


note "===== GET distinct =====";


test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems?fields=status&order=status&distinct=1" )));
    my $set = is_set_with_embedded_key($data, "ecosystems", 3,20);
    for my $item (@$set) {
        is keys %$item, 1, 'has one element';
        ok exists $item->{status}, 'has status element';
    }
};

done_testing();
