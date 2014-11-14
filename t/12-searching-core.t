#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok qw/basic/;

subtest "===== Paging =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

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
