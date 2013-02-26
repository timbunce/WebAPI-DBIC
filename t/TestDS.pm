#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;
use URI;
use Devel::Dwarn;

use parent 'Exporter';

use WebAPI::Config;

our @EXPORT = qw(
    url_query
    dsreq dsresp_json_data dsresp_ok
    is_set_with_embedded_key is_item
    get_data
);


sub _get_authorization_user_pass {
    # XXX TODO we ought to get the db realm name by querying the service
    our $db = WebAPI::Config->new->dbh('corp');
    return ($db->{user}, $db->{pass});
}


sub url_query {
    my ($url, %params) = @_;
    $url = URI->new( $url, 'http' );
    # encode any reference param values as JSON
    ref $_ and $_ = JSON->new->ascii->encode($_)
        for values %params;
    $url->query_form(%params);
    return $url;
}


sub dsreq {
    my ($method, $uri, $headers, $data) = @_;

    $headers = HTTP::Headers->new(@{$headers||[]});
    $headers->init_header('Content-Type' => 'application/json');
    $headers->init_header('Accept' => 'application/hal+json,application/json');
    $headers->authorization_basic(_get_authorization_user_pass())
        if not $headers->header('Authorization');

    my $content;
    if ($data) {
        $content = JSON->new->pretty->encode($data);
    }
    note("$method $uri");
    my $req = HTTP::Request->new($method => $uri, $headers, $content);
    return $req;
}

sub dsresp_json_data {
    my ($res) = @_;
    return undef unless $res->header('Content-type') =~ qr{^application/(?:hal\+)?json$};
    return undef unless $res->header('Content-Length');
    my $content = $res->content;
    my $data = JSON->new->decode($content);
    ok ref $data, 'response is a ref'
        or diag $content;
    return $data;
}

sub dsresp_ok {
    my ($res, $expect_status) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    #diag $res->as_string;
    status_matches($res, $expect_status || 200)
        or diag $res->as_string;
    my $data;
    $res->header('Content-type')
        and header_matches($res, 'Content-type', qr{^application/(?:hal\+)?json$})
        and $data = dsresp_json_data($res);
    return $data;
}

sub dsresp_created_ok {
    my ($res) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, 201)
        or diag $res->as_string;
    diag $res->as_string;
    my $location = $res->header('Location');
    ok $location, 'has Location header';
    my $data = dsresp_json_data($res);
    return $location unless wantarray;
    return ($location, $data);
}

sub is_set_with_embedded_key {
    my ($data, $key, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data->{_embedded}, "HASH", 'has _embedded hash';
    my $set = $data->{_embedded}{$key};
    is ref $set, "ARRAY", "_embedded has $key";
    cmp_ok scalar @$set, '>=', $min, "set has at least $min items"
        if defined $min;
    cmp_ok scalar @$set, '<=', $max, "set has at most $max items"
        if defined $max;
    return $set;
}

sub is_item {
    my ($data, $attributes) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    cmp_ok scalar keys %$data, '>=', $attributes, "set has less than $attributes attributes"
        if $attributes;
    return $data;
}

sub has_embedded {
    my ($data, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    is ref $data->{_embedded}, 'HASH', "_embedded isn't hash" or diag $data;
    my $e = $data->{_embedded};
    cmp_ok scalar keys %$e, '>=', $min, "set has less than $min attributes"
        if $min;
    cmp_ok scalar keys %$e, '<=', $max, "set has more than $max attributes"
        if $max;
    return $e;
}

sub is_error {
    my ($data, $attributes) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    cmp_ok scalar keys %$data, '>=', $attributes, "set has less than $attributes attributes"
        if $attributes;
    return $data;
}

sub get_data {
    my ($app, $url) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $data;
    test_psgi $app, sub { $data = dsresp_ok(shift->(dsreq( GET => $url ))) };
    return $data;
}

1;
