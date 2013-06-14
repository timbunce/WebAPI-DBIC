#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON;
use Sort::Key qw(multikeysorter);
use Carp;

use Devel::Dwarn;

use lib "t";
use TestDS;


my $app = require WebAPI::DBIC::WebApp;


sub is_ordered {
    my ($got, $value_sub, @types) = @_;

    my $sorter = multikeysorter($value_sub, @types);
    my @ordered = $sorter->(@$got);

    my @got_view = map { join "+", $value_sub->($_) } @$got;
    my @ord_view = map { join "+", $value_sub->($_) } @ordered;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    eq_or_diff_data \@got_view, \@ord_view, 'ordered';
}


note "===== Ordering =====";

my $base = "/person_types?rows=1000"; # rows must include all for tests to pass
my %person_types;
my @person_types;

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.id" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    @person_types = @$set;
    %person_types = map { $_->{id} => $_ } @person_types;
    is ref $person_types{$_}, "HASH", "/person_types includes $_"
        for (1..3);
    ok $person_types{1}{name}, "/person_types data looks sane";
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.id%20desc" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    is_deeply $set, [ reverse @person_types], 'reversed';
    is_ordered($set, sub { $_->{id} }, '-int');
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.name%20desc,id%20desc" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    cmp_deeply $set, bag(@person_types), 'same set of rows';
    ok not eq_deeply $set, \@person_types, 'order has changed';
    is_ordered($set, sub { lc $_->{name}, $_->{id} }, '-str', '-int');
};

test_psgi $app, sub {
    my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.name,id%20asc" )));
    my $set = is_set_with_embedded_key($data, "person_types", 2);
    cmp_deeply $set, bag(@person_types), 'same set of rows';
    ok not eq_deeply $set, \@person_types, 'order has changed';
    is_ordered($set, sub { lc $_->{name}, $_->{id} }, 'str', 'int');
};

note "===== Ordering with prefetch =====";

test_psgi $app, sub {
    # the extra me.* param is to make this query be less expensive
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people?prefetch=client_auth&order=client_auth.username&me.client_auth.demo=1" )));
    my $set = is_set_with_embedded_key($data, "ecosystems_people", 2);
    # XXX the s/\./~/g is a hack to workaround an apparent difference between
    # perl's lexical sorting and postgres character sorting
    # eg they order danielle.carne and daniel.rabiner differently
    is_ordered($set, sub { my $val = lc $_->{_embedded}{client_auth}{username}; $val=~s/\./~/g; $val }, 'str');
};

test_psgi $app, sub {
    # the extra me.* param is to make this query be less expensive
    my $data = dsresp_ok(shift->(dsreq( GET => "/ecosystems_people?prefetch=person,client_auth&order=person.last_name%20desc,client_auth.username%20asc&me.client_auth.demo=1" )));
    my $set = is_set_with_embedded_key($data, "ecosystems_people", 2);
    cmp_ok scalar @$set, '>=', 5, 'matched sufficient records';
    is_ordered($set, sub { lc $_->{_embedded}{person}{last_name}, lc $_->{_embedded}{client_auth}{username} }, '-str', 'str');
};

done_testing();
