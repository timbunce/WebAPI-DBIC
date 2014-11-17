package TestKit;

use base 'ToolSet';

ToolSet->use_pragma('strict');
ToolSet->use_pragma('warnings');
ToolSet->use_pragma(feature => 'say');
ToolSet->use_pragma('autodie');

ToolSet->export(
    'Test::Most'           => undef,
    'Test::HTTP::Response' => undef,
    'Test::DBIx::Class'    => undef,
    'Plack::Test'          => undef,
    'Devel::Dwarn'         => undef,
    'Data::Printer'        => undef,
    # app
    'WebAPI::DBIC::WebApp' => undef,
    # local t/lib modules
    'TestDS'               => undef,
    'TestDS_HAL'           => undef,
);

1;
