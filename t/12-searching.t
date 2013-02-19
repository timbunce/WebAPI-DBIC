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

test_psgi $app, sub {
    dsresp_ok(shift->(dsreq( GET => "/person_types?me.nonesuch=42" )), 400);
};

for my $id (1,2,3) {
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types?me.id=$id" )));
        my $set = is_set($data, "person_types", 1,1);
        eq_or_diff $set->[0], $person_types{$id}, 'record matches';
    };
};


done_testing();
