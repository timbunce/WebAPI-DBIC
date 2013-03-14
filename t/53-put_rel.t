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

note "===== Update a resource and related resources via PUT =====";

my $orig_item;
my $orig_location;

# create one to edit
test_psgi $app, sub {
    my $res = shift->(dsreq( POST => "/persons?prefetch=self", [], {
        full_name => $test_key_string,
        deleted_at => "2000-01-01",
        _embedded => {
            type => {
                name => $test_key_string,
                description => "foo",
            }
        }
    }));
    ($orig_location, $orig_item) = dsresp_created_ok($res);
};


test_psgi $app, sub {
    my $res = shift->(dsreq( PUT => "/persons/$orig_item->{id}?prefetch=self,type", [], {
        deleted_at => "2000-02-02 00:00:00",
        _embedded => {
            type => {
                description => "bar"
            }
        }
    }));
    my $data = dsresp_ok($res);

    is ref $data, 'HASH', 'return data';
    is $data->{full_name}, $test_key_string;
    is $data->{deleted_at}, "2000-02-02 00:00:00", 'has deleted_at';
    ok $data->{id}, 'has id assigned';

    is $data->{type_id}, $orig_item->{type_id}, 'has same type_id assigned';
    ok $data->{_embedded}, 'has _embedded';
    my $type = $data->{_embedded}{type};
    is $type->{description}, 'bar';
};

note "recheck data as a separate request";
test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/persons/$orig_item->{id}?prefetch=self,type")));
    is $data->{deleted_at}, "2000-02-02 00:00:00", 'has deleted_at';
    ok $data->{_embedded}, 'has _embedded';
    my $type = $data->{_embedded}{type};
    is $type->{description}, 'bar';
};

test_psgi $app, sub {
    dsresp_ok(shift->(dsreq( DELETE => "/persons/$orig_item->{id}")), 204);
};

done_testing();
