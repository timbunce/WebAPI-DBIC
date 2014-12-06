#!/usr/bin/env perl

# TODO: this ought to be split up, eg testing requests on Item vs Set resources


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

subtest "===== Prefetch =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

done_testing();

__DATA__
Config:
Accept: application/vnd.api+json

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
# Return artist 1 and all cds. Ordered to ensure test stability.
# Artist->search({artistid => 1}, {prefetch => 'cds'})
GET /artist/1?prefetch=cds&order=cds.cdid

Name: multi type relation (has_many) in prefetch on set
# Return all artists and all cds
# Artist->search({}, {prefetch => 'cds'})
GET /artist?prefetch=cds&order=me.artistid,cds.cdid&rows=2

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

Name: prefetch on set with partial response of prefetched items
GET /cd?rows=2&page=1&prefetch=artist,genre&fields=cdid,artist,genreid,genre.genreid,artist.artistid

Name: prefetch on item with partial response of prefetched item
GET /cd/1?prefetch=artist,genre&fields=cdid,artist,genreid,artist.artistid,genre.genreid
