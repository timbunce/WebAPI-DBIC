package TestDS;

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use URI;
use Devel::Dwarn;
use Carp;

use parent 'Exporter';


our @EXPORT = qw(
    url_query
    dsreq dsresp_json_data dsresp_ok dsresp_created_ok
    get_data
    is_item
);


$Carp::Verbose = 1;

$ENV{PLACK_ENV} ||= 'development'; # ensure env var is set

$| = 1;


sub _get_authorization_user_pass {
    return( $ENV{DBI_USER}||"", $ENV{DBI_PASS}||"" );
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
    $headers->init_header('Content-Type' => 'application/json')
        unless $headers->header('Content-Type');
    $headers->init_header('Accept' => 'application/json')
        unless $headers->header('Accept');
    $headers->authorization_basic(_get_authorization_user_pass())
        unless $headers->header('Authorization');

    my $content;
    if ($data) {
        $content = JSON->new->pretty->encode($data);
    }
    note("$method $uri");
    my $req = HTTP::Request->new($method => $uri, $headers, $content);
    note $req->as_string if $ENV{WEBAPI_DBIC_DEBUG};
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
        and $data = dsresp_json_data($res);
    return $data;
}

sub dsresp_created_ok {
    my ($res) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    status_matches($res, 201)
        or diag $res->as_string;
    my $location = $res->header('Location');
    ok $location, 'has Location header';
    my $data = dsresp_json_data($res);
    return $location unless wantarray;
    return ($location, $data);
}


sub is_error {
    my ($data, $attributes) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    cmp_ok scalar keys %$data, '>=', $attributes, "set has less than $attributes attributes"
        if defined $attributes;
    return $data;
}


sub is_item {
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
