package # hide from PAUSE
    TestSchema::Result::CD_to_Producer;

use warnings;
use strict;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('cd_to_producer');
__PACKAGE__->add_columns(
  cd => { data_type => 'integer' },
  producer => { data_type => 'integer' },
  attribute => { data_type => 'integer', is_nullable => 1 },
);
__PACKAGE__->set_primary_key(qw/cd producer/);

# the undef condition in this rel is *deliberate*
# tests oddball legacy syntax
__PACKAGE__->belongs_to(
  'cd', 'TestSchema::Result::CD'
);

__PACKAGE__->belongs_to(
  'producer', 'TestSchema::Result::Producer',
  { 'foreign.producerid' => 'self.producer' },
  { on_delete => undef, on_update => undef },
);

1;
