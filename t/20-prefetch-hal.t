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


test "===== Prefetch =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    # here we ask to prefetch items that have a belongs_to relationship with the resource
    # they get returned as _embedded objects. (Also they may be stale.)
    note "prefetch on item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd/1?prefetch=artist,genre" )));
        my $item = is_item($data, 1,1);
        my $embedded = has_hal_embedded($data, 2,2);
        is ref $embedded->{genre}, 'HASH', "has embedded genreid";
        is $embedded->{genre}{genreid}, $data->{genreid}, 'genreid matches';
        is ref $embedded->{artist}, 'HASH', "has embedded artistid";
        is $embedded->{artist}{artistid}, $data->{artist}, 'artistid matches';
    };

    note "prefetch on set";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd?rows=2&page=1&prefetch=artist,genre" )));
        my $set = has_hal_embedded_list($data, "cd", 2,2);
        for my $item (@$set) {
            my $embedded = has_hal_embedded($item, 2,2);
            is ref $embedded->{genre}, 'HASH', "has embedded genreid";
            is $embedded->{genre}{genreid}, $item->{genreid}, 'genreid matches';
            is ref $embedded->{artist}, 'HASH', "has embedded person_id";
            is $embedded->{artist}{artistid}, $item->{artist}, 'artistid matches';
        }
    };

    # Only handle filter of the SET based on the PREFETCH. DBIC won't allow filtering of the PREFETCH on an ITEM
    # as the WHERE clause is added to the whole select statement. IF custom where clauses are needed on the right
    # hand side of the join then these should be implemented as custom relationships
    # https://metacpan.org/pod/DBIx::Class::ResultSet#PREFETCHING

    # Should only return CDs whose artist is Caterwauler McCrae
    # CD->search({artist.name => 'Caterwauler McCrae']}, {prefetch => 'artist'})
    note "filter on prefetch with string";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd?prefetch=artist&artist.name=Caterwauler+McCrae")));
        my $set = has_hal_embedded_list($data, "cd", 3, 3);
        for my $item (@$set) {
            my $embedded = has_hal_embedded($item, 1, 1);
            is ref $embedded->{artist}, 'HASH', "has embedded artist";
            is $embedded->{artist}{name}, 'Caterwauler McCrae', 'artist has the correct name';
        }
    };

    # Should return the all CDs whose artist name ends wth McCrae
    # CD->search({artist.name => {'LIKE' => '%McCrae'}}, {prefetch => 'artist'})
    note "filter on prefetch with JSON";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => '/cd?prefetch=artist&artist.name~json={"like":"%McCrae"}')));
        my $set = has_hal_embedded_list($data, "cd", 3, 3);
        for my $item (@$set) {
            my $embedded = has_hal_embedded($item, 1, 1);
            is ref $embedded->{artist}, 'HASH', "has embessed artist";
            like $embedded->{artist}{name}, qr/McCrae$/, 'artist has the correct name';
        }
    };


    # Return all artists and all cds
    # Artist->search({}, {prefetch => 'cds'})
    note "multi type relation (has_many) in prefetch on set";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => '/artist?prefetch=cds&rows=2')));
        my $artists = has_hal_embedded_list($data, 'artist', 2,2);
        for my $artist (@$artists) {
            # { _embedded => { cds => { _embedded => [ {...}, ... ], }  }, artistid => 1, ... }
            my $cds = has_hal_embedded_list($artist, "cds", 1, 3);
            for my $cd (@$cds) {
               is $cd->{artist} => $artist->{artistid}, 'cd has the correct artistid';
            }
        }
    };

    # Return artist 1 and all cds
    # Artist->search({artistid => 1}, {prefetch => 'cds'})
    note "multi type relation (has_many) in prefetch on item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => '/artist/1?prefetch=cds')));
        my $item = is_item($data,1,1);
        my $cds = has_hal_embedded_list($item, "cds", 1, 3);
        for my $cd (@$cds) {
            is $cd->{artist} => $data->{artistid}, 'cd has the correct artistid';
        }
    };

    # Return all cds and all producers
    # cd->search({}, {prefetch => {cd_to_producers => 'producer'})
    # many_to_many relationships are not true db relationships. As such you can't use a many_to_many
    # in a prefetch but must traverse the join.
    note "multi type relation (many_to_many) in prefetch on item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => '/cd/1?prefetch~json={"cd_to_producer":"producer"}')));
        my $item = is_item($data,1,1);
        my $cd_to_producers = has_hal_embedded_list($item, 'cd_to_producer', 3, 3);
        for my $cd_to_producer (@$cd_to_producers){
            is $cd_to_producer->{cd} => $data->{cdid}, 'CD_to_Producer has correct cdid';
            my $embedded = has_hal_embedded($cd_to_producer, 1, 1);
            is ref $embedded->{producer}, 'HASH', 'has embedded producer';
            is $embedded->{producer}{producerid} => $cd_to_producer->{producer}, 'many_to_many join successful'
        }
    };

    # Return all artists who have a CD created after 1997 who's producer is Matt S Trout
    # Artist->search({cds.year => ['>', '1997'], producers.name => 'Matt S Trout'}, {prefetch => [{cds => producers}]})
    note "filter on nested prefetch";
    test_psgi $app, sub {
        my $data = dsresp_ok(
            shift->(
                dsreq_hal( GET => '/artist?prefetch~json={"cds":{"cd_to_producer":"producer"}}&cds.year~json={">":"1996"}&producer.name=Matt+S+Trout&rows=2')
            )
        );
        my $set = has_hal_embedded_list($data, "artist", 1, 1);
        for my $item (@$set) {
            my $cds = has_hal_embedded_list($item, 'cds', 1, 1);
            for my $cd (@$cds) {
                cmp_ok $cd->{year}, '>', '1996', 'CD year after 1996';
                my $cd_to_producers = has_hal_embedded_list($cd, 'cd_to_producer', 1, 1);
                for my $cd_to_producer (@$cd_to_producers){
                    is $cd_to_producer->{cd} => $cd->{cdid}, 'CD_to_Producer has correct cdid';
                    my $embedded = has_hal_embedded($cd_to_producer, 1, 1);
                    is ref $embedded->{producer}, 'HASH', 'has embedded producer';
                    is $embedded->{producer}{producerid} => $cd_to_producer->{producer}, 'many_to_many join successful';
                    is $embedded->{producer}{name} => 'Matt S Trout', 'has correct producer';
                }
            }
        }
    };

    note "prefetch with query on ambiguous field";
    # just check that a 'artist is ambiguous' error isn't generated
    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq_hal( GET => "/cd/?me.artist=1&prefetch=artist" )));
    };

    note "prefetch on invalid name";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd/1?prefetch=nonesuch" )), 400);
    };

    TODO: {
    local $TODO = "partial response of prefetched items is not implemented yet";

    note "prefetch on item with partial response of prefetched item";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd/1?prefetch=artist,genre&fields=cdid,genreid,artist.artistid,genre.genreid" )));
        my $item = is_item($data, 1,1);
        my $embedded = has_hal_embedded($data, 2,2);
        is ref $embedded->{genre}, 'HASH', "has embedded genreid";
        is $embedded->{genre}{genreid}, $data->{genreid}, 'genreid matches';
        is ref $embedded->{artist}, 'HASH', "has embedded artistid";
        is $embedded->{artist}{artistid}, $data->{artist}, 'artist matches';

        is keys %{ $embedded->{genre} }, 1, 'only has id column';
        is keys %{ $embedded->{artist} }, 1, 'only has id column';
    };

    note "prefetch on set with partial response of prefetched items";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_hal( GET => "/cd?rows=2&page=1&prefetch=artist,genre&fields=cdid,genreid,genre.genreid,artist.artistid" )));
        my $set = has_hal_embedded_list($data, "cd", 2,2);
        for my $item (@$set) {
            my $embedded = has_hal_embedded($item, 2,2);
            is ref $embedded->{genre}, 'HASH', "has embedded genreid";
            is $embedded->{genre}{genreid}, $item->{genreid}, 'genreid matches';
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
