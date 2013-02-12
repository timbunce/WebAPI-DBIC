#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

my $test_key_string = "clients_dataservice";

my $app = require WebAPI::DBIC::WebApp;

sub dsreq {
    my ($method, $uri, $headers, $data) = @_;

    my @headers = @{$headers || []};
    my %headers = @headers;
    push @headers, 'Content-Type' => 'application/json'
        unless $headers{'Content-Type'};
    push @headers, 'Accept' => 'application/json'
        unless $headers{'Accept'};

    my $content;
    if ($data) {
        $content = JSON->new->pretty->encode($data);
    }
    note("$method $uri");
    my $req = HTTP::Request->new($method => $uri, \@headers, $content);
    return $req;
}

sub dsresp_json_parcel {
    my ($res) = @_;
    return undef unless $res->header('Content-type') eq 'application/json';
    return undef unless $res->header('Content-Length');
    my $content = $res->content;
    my $parcel = JSON->new->decode($content);
    is ref $parcel, 'HASH', 'response is a HASH'
        or diag $content;
    ok ref $parcel->{data}, 'response contains a data element'
        or diag $content;
    return $parcel;
}

sub dsresp_ok {
    my ($res, $expect_status) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    #diag $res->as_string;
    status_matches($res, $expect_status || 200)
        or diag $res->as_string;
    my $parcel;
    header_matches($res, 'Content-type', 'application/json')
        and $parcel = dsresp_json_parcel($res);
    return $parcel;
}

sub dsresp_created_ok {
    my ($res) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, 201)
        or diag $res->as_string;
    diag $res->as_string;
    my $location = $res->header('Location');
    ok $location, 'has Location header';
    my $parcel = dsresp_json_parcel($res);
    return $location unless wantarray;
    return ($location, $parcel);
}

sub is_set {
    my ($parcel, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $data = $parcel->{data};
    is ref $data, 'ARRAY', "data isn't an array"
        or return;
    cmp_ok scalar @$data, '>=', $min, "set has less than $min items"
        if defined $min;
    cmp_ok scalar @$data, '<=', $max, "set has more than $max items"
        if defined $max;
    return $data;
}

sub is_item {
    my ($parcel, $attributes) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $data = $parcel->{data};
    is ref $data, 'HASH', "data isn't a hash";
    cmp_ok scalar keys %$data, '>=', $attributes, "set has less than $attributes attributes"
        if $attributes;
    return $data;
}

sub get_parcel {
    my ($url) = @_;
    my $parcel;
    test_psgi $app, sub { $parcel = dsresp_ok(shift->(dsreq( GET => $url ))) };
    return $parcel;
}


local $SIG{__DIE__} = \&Carp::confess;


my %person_types;

test_psgi $app, sub {
    my $parcel = dsresp_ok(shift->(dsreq( GET => "/person_types" )));
    my $data = is_set($parcel, 2);
    %person_types = map { $_->{data}{id} => $_->{data} } @$data;
    is ref $person_types{$_}, "HASH", "/person_types includes $_"
        for (1..5);
    ok $person_types{1}{name}, "/person_types data looks sane";
};

test_psgi $app, sub {
    my $parcel = dsresp_ok(shift->(dsreq( GET => "/person_types/1" )));
    my $data = is_item($parcel, 3);
    is $data->{id}, 1, 'id';
};

test_psgi $app, sub {
    my $parcel = dsresp_ok(shift->(dsreq( GET => "/person_types/2" )));
    my $data = is_item($parcel);
    is $data->{id}, 2, 'id';
};

my $item;

test_psgi $app, sub {
    my $desc = "dummy 1 description ".localtime();
    my $res = shift->(dsreq( POST => "/person_types", [], {
        name => $test_key_string,
        description => $desc,
    }));
    my ($location, $parcel) = dsresp_created_ok($res);
    $item = get_parcel($location)->{data};
    ok $item->{id}, 'new item has id';
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
    my ($location, $parcel) = dsresp_created_ok($res);
    $item = get_parcel($location)->{data};
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
