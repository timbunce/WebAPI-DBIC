#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

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

sub dsresp_ok {
    my ($res) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, 200)
        or diag $res->as_string;
    my $data;
    header_matches($res, 'Content-type', 'application/json')
        and $data = JSON->new->pretty->decode($res->content);
    return $data;
}

sub is_collection {
    my ($data, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'ARRAY', "data isn't an array";
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


#local $SIG{__DIE__} = \&Carp::confess;


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

=pod WIP

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        POST => "/person_types", [], {
        }
    )));
    is_item($data);
    is $data->{id}, 2, 'id';
    $tmp_obj = $data;
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq(
        PUT => "/person_types"
    )));
    is_item($data);
    is $data->{id}, 2, 'id';
};
=cut

done_testing();
