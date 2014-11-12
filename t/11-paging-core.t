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

Name: get 1 row
GET /artist?rows=1

Name: get 2 rows
GET /artist?rows=2

Name: get 2 rows from second 'page'
GET /artist?rows=2&page=2

