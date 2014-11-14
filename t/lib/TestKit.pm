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
    'TestDS'               => undef,
    'TestDS_HAL'           => undef,
    'Plack::Test'          => undef,
    'WebAPI::DBIC::WebApp' => undef,
    'Devel::Dwarn'         => undef,
    'Data::Printer'        => undef,
);

1;
