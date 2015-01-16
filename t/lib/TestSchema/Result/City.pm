package # Hide from PAUSE
    TestSchema::Result::City;

use strict;
use warnings;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('city');
__PACKAGE__->add_columns(
    'id' => {
        data_type           => 'int',
        is_numeric          => 1,
        is_auto_increment   => 1,
    },
    name => {
        data_type => 'text',
    },
    country_id => {
        data_type       => 'int',
        is_foreign_key  => 1,
        is_numeric      => 1,
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->belongs_to('country', 'TestSchema::Result::Country', 'country_id');

1;
