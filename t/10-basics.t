#!/usr/bin/env perl

use lib 't/lib';
use lib "t";

use Devel::Dwarn;
use JSON;
use Plack::Test;
use TestDS;
use Test::HTTP::Response;
use Test::Most;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};



local $SIG{__DIE__} = \&Carp::confess;

test '===== Get =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    });


    my %person_types;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types" )));
        my $set = is_set_with_embedded_key($data, "person_types", 2);
        %person_types = map { $_->{id} => $_ } @$set;
        is ref $person_types{$_}, "HASH", "/person_types includes $_"
            for (1..3);
        ok $person_types{1}{name}, "/person_types data looks sane";
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types/1" )));
        is_item($data, 3);
        is $data->{id}, 1, 'id';
        eq_or_diff $data, $person_types{$data->{id}}, 'data matches';
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/person_types/2" )));
        is_item($data, 3);
        is $data->{id}, 2, 'id';
        eq_or_diff $data, $person_types{$data->{id}}, 'data matches';
    };
};



after teardown => sub {
    my ($self) = @_;
    diag "Bye!";
};


run_me();
done_testing();
