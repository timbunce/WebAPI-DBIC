#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use TestDS_HAL;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


local $SIG{__DIE__} = \&Carp::confess;

after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};

test "===== Get with fields param =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    my %artist;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/artist?fields=artistid,name" )));
        my $set = has_hal_embedded_list($data, "artist", 2);
        %artist = map { $_->{artistid} => $_ } @$set;
        is ref $artist{$_}, "HASH", "/artist includes $_"
            for (1..3);
        ok $artist{1}{name}, "/artist data looks sane";
        ok !exists $artist{1}{rank}, 'rank fields not preset';
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/artist/1?fields=artistid,name" )));
        is_item($data, 2);
        is $data->{artistid}, 1, 'artistid';
        eq_or_diff $data, $artist{$data->{artistid}}, 'data matches';
    };

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/artist/2?fields=artistid,rank" )));
        is_item($data, 2);
        is $data->{artistid}, 2, 'artistid';
        ok exists $data->{rank}, 'has rank field';
    };
};

run_me();
done_testing();
