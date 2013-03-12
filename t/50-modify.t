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

note "===== Create - POST =====";

my $item;

my %person_types;
my @new_ids;
my $new_desc = "dummy desc ".time();

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/person_types" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    %person_types = map { $_->{id} => $_ } @$set;
    is ref $person_types{$_}, "HASH", "/person_types includes $_"
        for (1..3);
    ok $person_types{1}{name}, "/person_types data looks sane";
};

note "plain post";
test_psgi $app, sub {
    my $desc = "1 $new_desc";
    my $res = shift->(dsreq( POST => "/person_types", [], {
        name => $test_key_string,
        description => $desc,
    }));
    my ($location, $data) = dsresp_created_ok($res);
    is $data, undef, 'no data returned without prefetch';

    $item = get_data($app, $location);
    ok $item->{id}, 'new item has id'
        or diag $item;
    ok !$person_types{$item->{id}}, 'new item has new id';
    is $item->{name}, $test_key_string;
    is $item->{description}, $desc;

    push @new_ids, $item->{id};
};

note "post with prefetch=self";
test_psgi $app, sub {
    my $desc = "2 $new_desc";
    my $res = shift->(dsreq( POST => "/person_types?prefetch=self", [], {
        name => $test_key_string,
        description => $desc,
    }));
    my ($location, $data) = dsresp_created_ok($res);

    $item = get_data($app, $location);
    ok $item->{id}, 'new item has id';
    ok !$person_types{$item->{id}}, 'new item has new id';
    is $item->{name}, $test_key_string;
    is $item->{description}, $desc;

    eq_or_diff $data, $item, 'returned prefetch matches item at location';
    push @new_ids, $item->{id};
};


note "===== Update - PUT ====="; # uses previous $item

note "put without prefetch=self";
test_psgi $app, sub {
    my $desc = "foo";
    my $data = dsresp_ok(shift->(dsreq( PUT => "/person_types/$item->{id}", [], {
        id => $item->{id},
        name => $test_key_string,
        description => $desc,
    })), 204);
    is $data, undef, 'no response body';
    $item = get_data($app, "/person_types/$item->{id}");
    is $item->{description}, $desc;
};

note "put with prefetch=self";
test_psgi $app, sub {
    my $desc = "bar";
    Dwarn my $data = dsresp_ok(shift->(dsreq( PUT => "/person_types/$item->{id}?prefetch=self", [], {
        id => $item->{id},
        name => $test_key_string,
        description => $desc,
    })), 200);
    is ref $data, 'HASH', 'has response body';
    is $data->{description}, $desc, 'prefetch response has updated description';

    $item = get_data($app, "/person_types/$item->{id}");
    $data->{id} += 0; # XXX hack to normalize JSON serialization
    eq_or_diff $data, $item, 'returned prefetch matches item at location';
};


note "===== Delete - DELETE =====";

note "delete";

for my $id (@new_ids) {
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( DELETE => "/person_types/$id", [], {})), 204);
        is $data, undef, 'no response body';
    };
    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq( GET => "/person_types/$id", [], {})), 404);
    };
}

done_testing();
