#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;

use Devel::Dwarn;

use lib "t";
use TestDS;


my $app = require 'clients_dsapi.psgi'; # WebAPI::DBIC::WebApp;

local $SIG{__DIE__} = \&Carp::confess;

note "===== Prefetch =====";

# here we ask to prefetch items that have a belongs_to relationship with the resource
# they get returned as _embedded objects. (Also they may be stale.)

test_psgi $app, sub {
    Dwarn my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people/1?prefetch=person,client_auth" )));
    my $set = is_item($data, 1,1);
    my $embedded = has_embedded($data, 2,2);
    is ref $embedded->{client_auth}, 'HASH', "has embedded client_auth_id";
    is ref $embedded->{person}, 'HASH', "has embedded person_id";
};

done_testing();
