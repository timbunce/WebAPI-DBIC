package # hide from PAUSE
    TestSchema::Result::Track;

use warnings;
use strict;

use base qw(DBIx::Class::Core);

__PACKAGE__->load_components(qw{
    InflateColumn::DateTime
    Ordered
});

__PACKAGE__->table('track');
__PACKAGE__->add_columns(
  'trackid' => {
    data_type => 'integer',
    is_auto_increment => 1,
  },
  'cd' => {
    data_type => 'integer',
  },
  'position' => {
    data_type => 'int',
    accessor => 'pos',
  },
  'title' => {
    data_type => 'varchar',
    size      => 100,
  },
  last_updated_on => {
    data_type => 'datetime',
    accessor => 'updated_date',
    is_nullable => 1
  },
  last_updated_at => {
    data_type => 'datetime',
    is_nullable => 1
  },
);
__PACKAGE__->set_primary_key('trackid');

__PACKAGE__->add_unique_constraint([ qw/cd position/ ]);
__PACKAGE__->add_unique_constraint([ qw/cd title/ ]);

__PACKAGE__->position_column ('position');
__PACKAGE__->grouping_column ('cd');

# the undef condition in this rel is *deliberate*
# tests oddball legacy syntax
__PACKAGE__->belongs_to( cd => 'TestSchema::Result::CD', undef, {
    proxy => { cd_title => 'title' },
});

# custom condition coderef
__PACKAGE__->belongs_to( cd_cref_cond => 'TestSchema::Result::CD',
sub {
  my $args = shift;
  return (
    {
      "$args->{foreign_alias}.cdid" => { -ident => "$args->{self_alias}.cd" },
    },

    ( $args->{self_resultobj} ? {
     "$args->{foreign_alias}.cdid" => $args->{self_resultobj}->cd
    } : () ),

    ( $args->{foreign_resultobj} ? {
     "$args->{self_alias}.cd" => $args->{foreign_resultobj}->cdid
    } : () ),
  );
}
);
__PACKAGE__->belongs_to( disc => 'TestSchema::Result::CD' => 'cd', {
    proxy => 'year'
});

__PACKAGE__->might_have( cd_single => 'TestSchema::Result::CD', 'single_track' );


__PACKAGE__->has_many (
  next_tracks => __PACKAGE__,
  sub {
    my $args = shift;

    return (
      { "$args->{foreign_alias}.cd"       => { -ident => "$args->{self_alias}.cd" },
        "$args->{foreign_alias}.position" => { '>' => { -ident => "$args->{self_alias}.position" } },
      },
      $args->{self_resultobj} && {
        "$args->{foreign_alias}.cd"       => $args->{self_resultobj}->get_column('cd'),
        "$args->{foreign_alias}.position" => { '>' => $args->{self_resultobj}->pos },
      }
    )
  }
);

our $hook_cb;

sub sqlt_deploy_hook {
  my $class = shift;

  $hook_cb->($class, @_) if $hook_cb;
  $class->next::method(@_) if $class->next::can;
}

1;
