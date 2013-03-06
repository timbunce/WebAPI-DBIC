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

note "===== Get with fields param =====";

my %person_types;

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/person_types?fields=id,name" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    %person_types = map { $_->{id} => $_ } @$set;
    is ref $person_types{$_}, "HASH", "/person_types includes $_"
        for (1..3);
    ok $person_types{1}{name}, "/person_types data looks sane";
    ok !exists $person_types{1}{description}, 'description fields not preset';
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/person_types/1?fields=id,name" )));
    is_item($data, 2);
    is $data->{id}, 1, 'id';
    eq_or_diff $data, $person_types{$data->{id}}, 'data matches';
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/person_types/2?fields=id,description" )));
    is_item($data, 2);
    is $data->{id}, 2, 'id';
    ok exists $data->{description}, 'hash description field';
};

done_testing();
