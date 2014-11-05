#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
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


test "===== Create - POST =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    my $item;

    my %artists;
    my @new_ids;
    my $name = 'The Object-Relational Rapper';

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist" )));
        my $set = $data;
        %artists = map { $_->{artistid} => $_ } @$set;
        is ref $artists{$_}, "HASH", "/artist includes $_"
            for (1..3);
        ok $artists{1}{name}, "/artist data looks sane";
    };

    note "plain post";
    test_psgi $app, sub {
        my ($new_name, $rank) = qw(Funkicide 45);
        my $res = shift->(dsreq( POST => "/artist", [], {
            name => $new_name, rank => $rank,
        }));
        my ($location, $data) = dsresp_created_ok($res);
        is $data, undef, 'no data returned without prefetch';

        $item = get_data($app, $location);
        ok $item->{artistid}, 'new item has id'
            or diag $item;
        ok !$artists{$item->{artistid}}, 'new item has new id';
        is $item->{name}, $new_name;
        is $item->{rank}, $rank;

        push @new_ids, $item->{artistid};
    };

    note "post with prefetch=self";
    test_psgi $app, sub {
        my $rank = 12;
        my $res = shift->(dsreq( POST => "/artist?prefetch=self", [], {
            name => $name, rank => $rank,
        }));
        my ($location, $data) = dsresp_created_ok($res);

        $item = get_data($app, $location);
        ok $item->{artistid}, 'new item has id';
        ok !$artists{$item->{artistid}}, 'new item has new id';
        is $item->{name}, $name;
        is $item->{rank}, $rank;

        eq_or_diff $data, $item, 'returned prefetch matches item at location';
        push @new_ids, $item->{artistid};
    };


    note "===== Update - PUT ====="; # uses previous $item

    note "put without prefetch=self";
    test_psgi $app, sub {
        my $rank = 14;
        my $data = dsresp_ok(shift->(dsreq( PUT => "/artist/$item->{artistid}", [], {
            rank => $rank,
        })), 204);
        is $data, undef, 'no response body';
        $item = get_data($app, "/artist/$item->{artistid}");
        is $item->{rank}, $rank;
    };

    note "put with prefetch=self";
    test_psgi $app, sub {
        my $rank = 72;
        my $data = dsresp_ok(shift->(dsreq( PUT => "/artist/$item->{artistid}?prefetch=self", [], {
            rank => $rank,
        })), 200);
        is ref $data, 'HASH', 'has response body';
        is $data->{rank}, $rank, 'prefetch response has updated rank';

        $item = get_data($app, "/artist/$item->{artistid}");
        eq_or_diff $data, $item, 'returned prefetch matches item at location';
    };


    note "===== Delete - DELETE =====";

    for my $id (@new_ids) {
        test_psgi $app, sub {
            my $data = dsresp_ok(shift->(dsreq( DELETE => "/artist/$id", [], {})), 204);
            is $data, undef, 'no response body';
        };
        test_psgi $app, sub {
            dsresp_ok(shift->(dsreq( GET => "/person_types/$id", [], {})), 404);
        };
    }
};

run_me();
done_testing();
