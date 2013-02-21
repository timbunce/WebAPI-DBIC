#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

use lib "t";
use TestDS;


my $app = require 'clients_dsapi.psgi'; # WebAPI::DBIC::WebApp;

local $SIG{__DIE__} = \&Carp::confess;

note "===== Paging =====";

my %person_types;

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/person_types" )));
    my $set = is_set($data, "person_types", 2);
    %person_types = map { $_->{id} => $_ } @$set;
    is ref $person_types{$_}, "HASH", "/person_types includes $_"
        for (1..3);
    ok $person_types{1}{name}, "/person_types data looks sane";
};

for my $rows_param (1,2,3) {
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types?rows=$rows_param" )));
        my $set = is_set($data, "person_types", $rows_param, $rows_param);
        eq_or_diff $set->[$_], $person_types{$_+1}, 'record matches'
            for 0..$rows_param-1;
    };
};

for my $page (1,2,3) {
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types?rows=2&page=$page" )));
        my $set = is_set($data, "person_types", 2, 2);
        eq_or_diff $set->[$_], $person_types{ (($page-1)*2) + $_ + 1}, 'record matches'
            for 0..1;
    };
};

done_testing();
