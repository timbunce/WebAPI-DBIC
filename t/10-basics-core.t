#!/usr/bin/env perl

use Devel::Dwarn;
use JSON::MaybeXS;
use Plack::Test;
use Test::HTTP::Response;
use Test::Most;

use lib 't/lib';
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};



local $SIG{__DIE__} = \&Carp::confess;

test '===== Get - single field key =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    my %artist;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist" )));
        %artist = map { $_->{artistid} => $_ } @$data;
        is ref $artist{$_}, "HASH", "/artist includes $_"
            for (1..6);
        is $artist{1}{name}, "Caterwauler McCrae", "/artist data looks sane";
        is $artist{1}{rank}, 13, "/artist data looks sane";
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist/1" )));
        is_item($data, 3);
        is $data->{artistid}, 1, 'artistid';
        eq_or_diff $data, $artist{$data->{artistid}}, 'data matches';
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist/2" )));
        is_item($data, 3);
        is $data->{artistid}, 2, 'artistid';
        eq_or_diff $data, $artist{$data->{artistid}}, 'data matches';
    };

};


test '===== Get - multi-field key =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/gig/1/2014-01-01T01:01:01Z")));
        is_item($data, 1);
        is $data->{artistid}, 1, 'artistid';
        is $data->{gig_datetime}, '2014-01-01T01:01:01Z', 'gig_datetime';
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/gig/2/2014-06-30T19:00:00Z")));
        is_item($data, 1);
        is $data->{artistid}, 2, 'artistid';
        is $data->{gig_datetime}, '2014-06-30T19:00:00Z', 'gig_datetime';
    };

};


after teardown => sub {
    my ($self) = @_;
    note "Bye!";
};


run_me();
done_testing();
