package DummyLoadedSchema;

# Act enough like a DBIx::Class schema to let connect() to work
# eg so it can be used by webapi-dbic-any.psgi as a demo
# 
# WEBAPI_DBIC_SCHEMA=DummyLoadedSchema plackup -Ilib -It/lib webapi-dbic-any.psgi

use Test::DBIx::Class;
use DBIx::Class::Fixtures;

sub connect {
    DBIx::Class::Fixtures->new({config_dir => 't/etc/fixtures'})->populate({no_deploy => 1, schema => Schema, directory => 't/etc/fixtures/basic'});
    return Schema;
}

1;
