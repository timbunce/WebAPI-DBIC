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


test "===== Prefetch =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    # here we ask to prefetch items that have a belongs_to relationship with the resource
    # they get returned as _embedded objects. (Also they may be stale.)

    note "prefetch on item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd/1?prefetch=artist,genre" )));
        my $item = is_item($data, 1,1);
        my $embedded = has_embedded($data, 2,2);
        is ref $embedded->{genre}, 'HASH', "has embedded genreid";
        is $embedded->{genre}{genreid}, $data->{genreid}, 'genreid matches';
        is ref $embedded->{artist}, 'HASH', "has embedded artistid";
        is $embedded->{artist}{artistid}, $data->{artist}, 'artistid matches';
    };

    note "prefetch on set";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd?rows=2&page=1&prefetch=artist,genre" )));
        my $set = is_set_with_embedded_key($data, "cd", 2,2);
        for my $item (@$set) {
            my $embedded = has_embedded($item, 2,2);
            is ref $embedded->{genre}, 'HASH', "has embedded genreid";
            is $embedded->{genre}{genreid}, $item->{genreid}, 'genreid matches';
            is ref $embedded->{artist}, 'HASH', "has embedded person_id";
            is $embedded->{artist}{artistid}, $item->{artist}, 'artistid matches';
        }
    };

    note "prefetch with query on ambiguous field";
    # just check that a 'artist is ambiguous' error isn't generated
    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq( GET => "/cd?me.artist=1&prefetch=artist" )));
    };

    note "prefetch on invalid name";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd/1?prefetch=nonesuch" )), 400);
    };


    TODO: {
    local $TODO = "partial response of prefetched items is not implemented yet";

    note "prefetch on item with partial response of prefetched item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd/1?prefetch=artist,genre&fields=cdid,artist.artistid,genre.genreid" )));
        my $item = is_item($data, 1,1);
        my $embedded = has_embedded($data, 2,2);
        is ref $embedded->{genre}, 'HASH', "has embedded genreid";
        is $embedded->{genre}{genreid}, $data->{genreid}, 'genreid matches';
        is ref $embedded->{artist}, 'HASH', "has embedded artistid";
        is $embedded->{artist}{artistid}, $data->{artist}, 'artist matches';

        is keys %{ $embedded->{genre} }, 1, 'only has id column';
        is keys %{ $embedded->{artist} }, 1, 'only has id column';
    };

    note "prefetch on set with partial response of prefetched items";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd?rows=2&page=1&prefetch=artist,genre&fields=id,genre.genreid,artist.artistid" )));
        my $set = is_set_with_embedded_key($data, "cd", 2,2);
        for my $item (@$set) {
            my $embedded = has_embedded($item, 2,2);
            is ref $embedded->{genre}, 'HASH', "has embedded genreid";
            is $embedded->{genre}{id}, $item->{genreid}, 'genreid matches';
            is ref $embedded->{artist}, 'HASH', "has embedded artistid";
            is $embedded->{artist}{artistid}, $item->{artist}, 'artistid matches';

            is keys %{ $embedded->{genre} }, 1, 'only has id column';
            is keys %{ $embedded->{artist} }, 1, 'only has id column';
        }
    };

    } # end TODO

};

run_me();
done_testing();
