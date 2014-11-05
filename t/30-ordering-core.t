#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use Sort::Key qw(multikeysorter);
use Carp;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


local $SIG{__DIE__} = \&Carp::confess;

after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};


sub is_ordered {
    my ($got, $value_sub, @types) = @_;

    my $sorter = multikeysorter($value_sub, @types);
    my @ordered = $sorter->(@$got);

    my @got_view = map { join "/", $value_sub->($_) } @$got;
    my @ord_view = map { join "/", $value_sub->($_) } @ordered;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    eq_or_diff_data \@got_view, \@ord_view, 'ordered';
}

sub hack_str {
    my $str = shift;
    # XXX the s/\./~/g is a hack to workaround an apparent difference between
    # perl's lexical sorting and postgres character sorting
    # eg they order 'danielle.carne' vs 'daniel.rabiner' and
    # 'salesman' vs 'sales team' differently. Unicode collation?
    $str =~ s/ /~/g;
    return lc $str;
}


test "===== Ordering =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    my $base = "/cd?rows=1000"; # rows count must include all rows in set for tests to pass
    my %cds;
    my @cds;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.cdid" )));
        @cds = @$data;
        %cds = map { $_->{cdid} => $_ } @cds;
        is ref $cds{$_}, "HASH", "/cd includes $_"
            for (1..3);
        ok $cds{1}{title}, "/cd data looks sane";
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.cdid%20desc" )));
        is_deeply $data, [ reverse @cds], 'reversed';
        is_ordered($data, sub { $_->{cdid} }, '-int');
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.title%20desc,cdid%20desc" )));
        my $set = $data;
        cmp_deeply $set, bag(@cds), 'same set of rows returned';
        ok not eq_deeply $set, \@cds, 'order has changed from original';
        # XXX the s/\./~/g is a hack to workaround an apparent difference between
        # perl's lexical sorting and postgres character sorting
        # eg they order danielle.carne and daniel.rabiner differently
        is_ordered($set, sub { return hack_str($_->{title}), $_->{cdid} }, '-str', '-int');
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "$base&order=me.title,cdid%20asc" )));
        my $set = $data;
        cmp_deeply $set, bag(@cds), 'same set of rows returned';
        ok not eq_deeply $set, \@cds, 'order has changed from original';
        is_ordered($set, sub { return hack_str($_->{title}), $_->{cdid} }, 'str', 'int');
    };

};

run_me();
done_testing();
