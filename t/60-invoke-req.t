#!/usr/bin/env perl

use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

my $app = TestWebApp->new({
    routes => [
        {
            set => Schema->source('Artist'),
            invokeable_methods_on_item => [qw(get_column)],
            invokeable_methods_on_set  => [qw(count)],
        },
    ]
})->to_psgi_app;

subtest "===== Invoke methods =====" => sub {
    my ($self) = @_;

    run_request_spec_tests($app, \*DATA);
};

done_testing;

__DATA__
Config:

Name: Invoke get_column('name') on Item
POST /artist/1/invoke/get_column
{ "args" : ["name"] }

Name: Invoke get_column({}) on Item - Invalid arg type
POST /artist/1/invoke/get_column
{ "args" : {} }

Name: Invoke get_column() on Item - Unknown attribute
POST /artist/1/invoke/get_column
{ "nonesuch" : 1 }

Name: Invoke get_column() on Item - Invalid Body
POST /artist/1/invoke/get_column
[]

Name: Invoke get_colum('nonesuch') on Item - Invalid column
POST /artist/1/invoke/get_column
{ "args" : ["nonesuch"] }

Name: Invoke get_column('name') on Set
POST /artist/invoke/get_column
{ "args" : ["name"] }

Name: Invoke count on Set
POST /artist/invoke/count
{ }

Name: Invoke count on Set - Invalid arg type
POST /artist/invoke/count
{ "args" : {} }

Name: Invoke count on Set - Unknown attribute
POST /artist/invoke/count
{ "nonesuch" : 1 }

Name: Invoke count on Set - Invalid Body
POST /artist/invoke/count
[ ]

Name: Invoke count({name => "Caterwauler McCrae"}) on Set
POST /artist/invoke/count
{ "args" : [ { "name" : "Caterwauler McCrae" } ] }

Name: Invoke count on Item
POST /artist/1/invoke/count
{ }
