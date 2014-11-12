#!/usr/bin/env perl

use Test::Most;
use Devel::Dwarn;
use autodie;

use lib 't/lib';
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};



#local $SIG{__DIE__} = \&Carp::confess;



test '===== basics - specs =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};


after teardown => sub {
    my ($self) = @_;
    note "Bye!";
};


run_me();
done_testing();

__DATA__
Config:
Accept: application/hal+json,application/json

Name: get single item
GET /artist/1

Name: get different single item
GET /artist/2

Name: get set of items
GET /artist

Name: get item with multi-field key
GET /gig/1/2014-01-01T01:01:01Z

Name: get different item with multi-field key
GET /gig/2/2014-06-30T19:00:00Z
