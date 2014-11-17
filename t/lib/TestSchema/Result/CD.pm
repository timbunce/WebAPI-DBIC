package # hide from PAUSE
    TestSchema::Result::CD;

use warnings;
use strict;

use base qw(DBIx::Class::Core);

# this tests table name as scalar ref
# DO NOT REMOVE THE \
__PACKAGE__->table(\'cd');

__PACKAGE__->add_columns(
  'cdid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'artist' => {
    data_type => 'integer',
  },
  'title' => {
    data_type => 'varchar',
    size      => 100,
  },
  'year' => {
    data_type => 'varchar',
    size      => 100,
  },
  'genreid' => {
    data_type => 'integer',
    is_nullable => 1,
    accessor => undef,
  },
  'single_track' => {
    data_type => 'integer',
    is_nullable => 1,
    is_foreign_key => 1,
  }
);
__PACKAGE__->set_primary_key('cdid');
__PACKAGE__->add_unique_constraint([ qw/artist title/ ]);

__PACKAGE__->belongs_to( artist => 'TestSchema::Result::Artist', 'artist', {
    is_deferrable => 1,
});

# in case this is a single-cd it promotes a track from another cd
__PACKAGE__->belongs_to( single_track => 'TestSchema::Result::Track',
  { 'foreign.trackid' => 'self.single_track' },
  { join_type => 'left'},
);

# add a non-left single relationship for the complex prefetch tests
__PACKAGE__->belongs_to( existing_single_track => 'TestSchema::Result::Track',
  { 'foreign.trackid' => 'self.single_track' },
);

__PACKAGE__->has_many( tracks => 'TestSchema::Result::Track' );
__PACKAGE__->has_many(
    cd_to_producer => 'TestSchema::Result::CD_to_Producer' => 'cd'
);


__PACKAGE__->many_to_many( producers => cd_to_producer => 'producer' );
__PACKAGE__->many_to_many(
    producers_sorted => cd_to_producer => 'producer',
    { order_by => 'producer.name' },
);

__PACKAGE__->belongs_to('genre', 'TestSchema::Result::Genre',
    'genreid',
    {
        join_type => 'left',
        on_delete => 'SET NULL',
        on_update => 'CASCADE',
    },
);



1;
