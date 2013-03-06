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

local $SIG{USR2} = \&Carp::cluck;

note "prefetch on item";
test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people/1?prefetch=person,client_auth" )));
    my $item = is_item($data, 1,1);
    my $embedded = has_embedded($data, 2,2);
    is ref $embedded->{client_auth}, 'HASH', "has embedded client_auth_id";
    is $embedded->{client_auth}{id}, $data->{client_auth_id}, 'client_auth_id matches';
    is ref $embedded->{person}, 'HASH', "has embedded person_id";
    is $embedded->{person}{id}, $data->{person_id}, 'person_id matches';
};

note "prefetch on set";
test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people?rows=2&page=3&prefetch=person,client_auth" )));
    my $set = is_set_with_embedded_key($data, "ecosystems_people", 2,2);
    for my $item (@$set) {
        my $embedded = has_embedded($item, 2,2);
        is ref $embedded->{client_auth}, 'HASH', "has embedded client_auth_id";
        is $embedded->{client_auth}{id}, $item->{client_auth_id}, 'client_auth_id matches';
        is ref $embedded->{person}, 'HASH', "has embedded person_id";
        is $embedded->{person}{id}, $item->{person_id}, 'person_id matches';
    }
};

note "prefetch on invalid name";
test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people/1?prefetch=nonesuch" )), 400);
};


TODO: {
local $TODO = "partial response of prefetched items is not implemented yet";

note "prefetch on item with partial response of prefetched item";
test_psgi $app, sub {
   Dwarn  my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people/1?prefetch=person,client_auth&fields=id,client_auth.id,person.id" )));
    my $item = is_item($data, 1,1);
    my $embedded = has_embedded($data, 2,2);
    is ref $embedded->{client_auth}, 'HASH', "has embedded client_auth_id";
    is $embedded->{client_auth}{id}, $data->{client_auth_id}, 'client_auth_id matches';
    is ref $embedded->{person}, 'HASH', "has embedded person_id";
    is $embedded->{person}{id}, $data->{person_id}, 'person_id matches';

    is keys %{ $embedded->{client_auth} }, 1, 'only has id column';
    is keys %{ $embedded->{person} }, 1, 'only has id column';
};

note "prefetch on set with partial response of prefetched items";
test_psgi $app, sub {
    Dwarn my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people?rows=2&page=3&prefetch=person,client_auth&fields=id,client_auth.id,person.id" )));
    my $set = is_set_with_embedded_key($data, "ecosystems_people", 2,2);
    for my $item (@$set) {
        my $embedded = has_embedded($item, 2,2);
        is ref $embedded->{client_auth}, 'HASH', "has embedded client_auth_id";
        is $embedded->{client_auth}{id}, $item->{client_auth_id}, 'client_auth_id matches';
        is ref $embedded->{person}, 'HASH', "has embedded person_id";
        is $embedded->{person}{id}, $item->{person_id}, 'person_id matches';

        is keys %{ $embedded->{client_auth} }, 1, 'only has id column';
        is keys %{ $embedded->{person} }, 1, 'only has id column';
    }
};

}

done_testing();
