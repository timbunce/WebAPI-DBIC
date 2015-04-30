#!perl

BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for author testing');
  }
}

use Test::More;

eval "use Test::Spelling";
if ( $@ ) {
  plan skip_all => 'Test::Spelling required for testing POD';
} 
else {          
  add_stopwords(qw(
	Tim
	Bunce
	Axel 
    Stevan	
	Fitz
    Rabbitson
    fREW	
	
	CMS 
	DSN
    UML
	ORM
	ETag
    LD
    psgi
    RESTful
	
	Erlang
    Mojolicious
    DBIC
    WAPID

	INTEGRATIONS
	JSONAPI

    PREFETCHING
    Prefetch
    prefetch
    Prefetching
    prefetches
    prefetched
    prefetching

    RapidApp
    ResultSet

    TODO
    TBD

    adaptor
    browseable
    drinkup

    lowercased
    mis
    nolinks
    param
    params

    refactoring
    
    rought
    routings

    designator
    discoverability
    discoverable

    schemas
    GenericCore

    resultset

    resultsets
    ActiveModel

    extensibility
    explorable
    
  ));
  all_pod_files_spelling_ok();
}


