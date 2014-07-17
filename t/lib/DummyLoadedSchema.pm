package DummyLoadedSchema;

# Act enough like a DBIx::Class schema to let connect() to work
# eg so it can be used by webapi-dbic-any.psgi as a demo
# 
# WEBAPI_DBIC_SCHEMA=DummyLoadedSchema plackup -Ilib -It/lib webapi-dbic-any.psgi

use DummySchema;

sub connect {
    my $class = shift;

    my $dummy = DummySchema->new;
    $dummy->load_fixtures('basic');
    my $schema = $dummy->schema;

    return $schema->connect(@_);
}

1;
