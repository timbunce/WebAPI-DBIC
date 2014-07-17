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

test '===== Get =====' => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    my %artist;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist" )));
        my $set = is_set_with_embedded_key($data, "artist", 2);
        %artist = map { $_->{artistid} => $_ } @$set;
        is ref $artist{$_}, "HASH", "/artist includes $_"
            for (1..3);
        ok $artist{1}{name}, "/artist data looks sane";
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



after teardown => sub {
    my ($self) = @_;
    note "Bye!";
};


run_me();
done_testing();
