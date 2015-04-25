#!/usr/bin/env perl

# TODO: this ought to be split up, eg testing requests on Item vs Set resources


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

subtest "===== join =====" => sub {
    my ($self) = @_;

    my $app = TestWebApp->new({
        schema => Schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

};

done_testing();

__DATA__
Config:
Accept: application/vnd.api+json

Name: join on an item using two belongs_to relationships
GET /cd/1?join=artist,genre

Name: join on a set using two belongs_to relationships
GET /cd?rows=2&page=1&join=artist,genre

Name: filter on joined relation field
# Only handle filter of the SET based on the join. DBIC won't allow filtering of the join on an ITEM
# as the WHERE clause is added to the whole select statement.
# Should only return CDs whose artist is Caterwauler McCrae
GET /cd?join=artist&artist.name=Random+Boy+Band

Name: filter on join with JSON
GET /cd?join=artist PARAMS: artist.name~json=>{"like"=>"%Band"}

Name: multi type relation (has_many) in join on item
# Return artist 1 and all cds. Ordered to ensure test stability.
# Artist->search({artistid => 1}, {join => 'cds'})
GET /artist/1?join=cds&order=cds.cdid

Name: multi type relation (has_many) in join on set
# Return all artists and all cds
# Artist->search({}, {join => 'cds'})
GET /artist?join=cds&order=me.artistid,cds.cdid&rows=2

Name: multi type relation in join on item (many_to_many via JSON) ArrayRef Syntax
# Return all cds and all producers
# cd->search({}, {join => [{cd_to_producers => 'producer'}])
# many_to_many relationships are not true db relationships. As such you can't use a many_to_many
# in a join but must traverse the join.
GET /cd/1 PARAMS: join~json=>[{"cd_to_producer"=>"producer"}]

Name: multi type relation in join on item (many_to_many via JSON) HashRef Syntax
# Return all cds and all producers
# cd->search({}, {join => [{cd_to_producers => 'producer'}])
# many_to_many relationships are not true db relationships. As such you can't use a many_to_many
# in a join but must traverse the join.
GET /cd/1 PARAMS: join~json=>{"cd_to_producer"=>"producer"}

Name: filter on nested join
# Return all artists who have a CD created after 1997 who's producer is Matt S Trout
# Artist->search({cds.year => ['>', '1997'], producers.name => 'Matt S Trout'}, {join => [{cds => producers}]})
GET /artist?rows=2&producer.name=Matt+S+Trout PARAMS: join~json=>{"cds"=>{"cd_to_producer"=>"producer"}} cds.year~json=>{">","0996"}

Name: join with query on ambiguous field
# just check that a 'artist is ambiguous' error isn't generated
GET /cd/?me.artist=1&join=artist

Name: join on invalid name
GET /cd/1?join=nonesuch

Name: join on set with partial response of joined items
GET /cd?rows=2&page=1&join=artist,genre&fields=cdid,artist,genreid,genre.genreid,artist.artistid

Name: join on item with partial response of joined item
GET /cd/1?join=artist,genre&fields=cdid,artist,genreid,artist.artistid,genre.genreid

Name: join on item with id primary key #28
GET /country/1?join=cities
