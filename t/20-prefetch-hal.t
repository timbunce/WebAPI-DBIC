#!/usr/bin/env perl

# TODO: this ought to be split up, eg testing requests on Item vs Set resources


use lib "t/lib";
use TestKit;

fixtures_ok qw/basic/;

subtest "===== Prefetch =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

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

done_testing();

__DATA__
Config:
Accept: application/hal+json,application/json

Name: prefetch on an item using two belongs_to relationships
GET /cd/1?prefetch=artist,genre

Name: prefetch on a set using two belongs_to relationships
GET /cd?rows=2&page=1&prefetch=artist,genre

Name: filter on prefetched relation field
# Only handle filter of the SET based on the PREFETCH. DBIC won't allow filtering of the PREFETCH on an ITEM
# as the WHERE clause is added to the whole select statement.
# Should only return CDs whose artist is Caterwauler McCrae
GET /cd?prefetch=artist&artist.name=Random+Boy+Band

Name: filter on prefetch with JSON
GET /cd?prefetch=artist PARAMS: artist.name~json=>{"like"=>"%Band"}

Name: multi type relation (has_many) in prefetch on item
# Return artist 1 and all cds
# Artist->search({artistid => 1}, {prefetch => 'cds'})
GET /artist/1?prefetch=cds

Name: multi type relation (has_many) in prefetch on set
# Return all artists and all cds
# Artist->search({}, {prefetch => 'cds'})
GET /artist?prefetch=cds&rows=2

Name: multi type relation in prefetch on item (many_to_many via JSON)
# Return all cds and all producers
# cd->search({}, {prefetch => {cd_to_producers => 'producer'})
# many_to_many relationships are not true db relationships. As such you can't use a many_to_many
# in a prefetch but must traverse the join.
GET /cd/1 PARAMS: prefetch~json=>{"cd_to_producer"=>"producer"}

Name: filter on nested prefetch
# Return all artists who have a CD created after 1997 who's producer is Matt S Trout
# Artist->search({cds.year => ['>', '1997'], producers.name => 'Matt S Trout'}, {prefetch => [{cds => producers}]})
GET /artist?rows=2&producer.name=Matt+S+Trout PARAMS: prefetch~json=>{"cds"=>{"cd_to_producer"=>"producer"}} cds.year~json=>{">","0996"}

Name: prefetch with query on ambiguous field
# just check that a 'artist is ambiguous' error isn't generated
GET /cd/?me.artist=1&prefetch=artist

Name: prefetch on invalid name
GET /cd/1?prefetch=nonesuch
