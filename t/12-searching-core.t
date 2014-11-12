#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use URI;
use URI::QueryParam;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};


local $SIG{__DIE__} = \&Carp::confess;

test "===== Paging =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};


run_me();
done_testing();

__DATA__
Config:

Name: get 1 row from set by qualifying the key
GET /artist?me.artistid=2

Name: get specific rows via json array
GET /artist PARAMS: me.artistid~json=>[1,3]

Name: get specific rows via json qualifier expression
GET /artist PARAMS: me.artistid~json=>{"<=",2}

Name: get no rows, empty set, due to qualifier that matches none
GET /artist?me.artistid=999999

Name: invalid request due to qualifying by non-existant field
SKIP need to add post-processing of the error result
GET /artist?me.nonesuch=42
