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

local $SIG{__DIE__} = \&Carp::confess;

note "===== Create =====";

my $item;

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
#local $ENV{WM_DEBUG} = 1;
    my $desc = "dummy 1 description ".localtime();
    my $res = shift->(dsreq( POST => "/person_types", [], {
        name => $test_key_string,
        description => $desc,
    }));
diag $res->as_string;
    my ($location, $data) = dsresp_created_ok($res);
    $item = get_data($app, $location);
    ok $item->{id}, 'new item has id'
        or diag $item;
    ok !$person_types{$item->{id}}, 'new item has new id';
    is $item->{name}, $test_key_string;
    is $item->{description}, $desc;
};

test_psgi $app, sub {
    my $desc = "dummy 2 description ".localtime();
    my $res = shift->(dsreq( POST => "/person_types", [], {
        name => $test_key_string,
        description => $desc,
    }));
    my ($location, $data) = dsresp_created_ok($res);
    $item = get_data($app, $location);
    ok $item->{id}, 'new item has id';
    ok !$person_types{$item->{id}}, 'new item has new id';
    is $item->{name}, $test_key_string;
    is $item->{description}, $desc;
};


=pod WIP
test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        PUT => "/person_types"
    )));
    is_item($data);
    is $data->{id}, 2, 'id';
};
=cut

done_testing();
