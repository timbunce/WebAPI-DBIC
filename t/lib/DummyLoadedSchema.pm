package DummyLoadedSchema;

# Act enough like a DBIx::Class schema to let connect() to work
# eg so it can be used by webapi-dbic-any.psgi as a demo
# 
# WEBAPI_DBIC_SCHEMA=DummyLoadedSchema plackup -Ilib -It/lib webapi-dbic-any.psgi

use Test::DBIx::Class;

sub connect {
    fixtures_ok('basic');
    return Schema;
}

1;
