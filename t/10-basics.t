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

sub dsresp_json_data {
    my ($res) = @_;
    return undef unless $res->header('Content-type') eq 'application/json';
    my $content = $res->content;
    return undef unless length $content;
    return JSON->new->pretty->decode($content)
}

sub dsresp_ok {
    my ($res, $expect_status) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, $expect_status || 200)
        or diag $res->as_string;
    my $data;
    header_matches($res, 'Content-type', 'application/json')
        and $data = dsresp_json_data($res);
    return $data;
}

sub dsresp_created_ok {
    my ($res) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, 201)
        or diag $res->as_string;
diag $res->as_string;
    my $location = $res->header('Content-type');
    ok $location, 'has Location header';
    my $data = dsresp_json_data($res);
    return $location unless wantarray;
    return ($location, $data);
}

sub is_collection {
    my ($data, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'ARRAY', "data isn't an array"
        or return;
    cmp_ok scalar @$data, '>=', $min, "collection has less than $min items"
        if defined $min;
    cmp_ok scalar @$data, '<=', $max, "collection has more than $max items"
        if defined $max;
}

sub is_item {
    my ($data, $attributes) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    cmp_ok scalar keys %$data, '>=', $attributes, "collection has less than $attributes attributes"
        if $attributes;
}


local $SIG{__DIE__} = \&Carp::confess;


test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        GET => "/person_types"
    )));
    is_collection($data, 2);
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        GET => "/person_types/1"
    )));
    is_item($data, 3);
    is $data->{id}, 1, 'id';
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        GET => "/person_types/2"
    )));
    is_item($data);
    is $data->{id}, 2, 'id';
};

my $tmp_obj;

test_psgi $app, sub {
    my $res = shift->(dsreq(
        POST => "/person_types", [], {
            name => $test_key_string,
            description => "dummy description ".localtime(),
        }
    ));
    my ($location, $data) = dsresp_created_ok($res);
    #is $data->{id}, 2, 'id';
    #$tmp_obj = $data;
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
