package # Hide from Pause
    TestSchema::Result::Gig;

use strict;
use warnings;

use base qw(DBIx::Class::Core);

# A Test schema result class for Gigs at a venue.
# Designed for testing dual primary keys where one is a
# datetime

__PACKAGE__->load_components(qw(InflateColumn::DateTime));

__PACKAGE__->table('gig');
__PACKAGE__->add_columns(
    'artistid' => {
        data_type       => 'Integer',
        is_foreign_key  => 1,
        is_numeric      => 1,
    },
    'gig_datetime' => {
        data_type       => 'varchar',
        size            => 30,
    },
);

__PACKAGE__->set_primary_key(qw/artistid gig_datetime/);

# SQLite doesn't support the DateTime data type. Thus we can't use
# InflateColumn::DateTime so we have to do it manually here.
__PACKAGE__->inflate_column('gig_datetime' => {
    'inflate' => sub {
        my ($db_value, $gig) = @_;

        return DateTime::Format::SQLite->parse_datetime($db_value);
    },
    'deflate' => sub {
        my ($date_datetime, $gig) = @_;

        return "$date_datetime";
    },
});

# Relationships
__PACKAGE__->belongs_to(artist => 'TestSchema::Result::Artist', 'artistid');

1;
