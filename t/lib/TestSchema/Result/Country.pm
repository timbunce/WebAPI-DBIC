package # Hide from PAUSE
    TestSchema::Result::Country;

use warnings;
use strict;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table('country');
__PACKAGE__->add_columns(
    'id' => {
        data_type           => 'integer',
        is_auto_increment   => 1,
        is_numeric          => 1,
    },
    'name' => {
        data_type   => 'text',
    },
);

__PACKAGE__->set_primary_key('id');

__PACKAGE__->has_many('cities' => 'TestSchema::Result::City','country_id');

1;
