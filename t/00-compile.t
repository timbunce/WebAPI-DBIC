use strict;
use warnings;

use Test::More 0.98;

use Module::Pluggable search_path
    => [ qw(WebAPI::DBIC WebAPI::HTTP::Throwable) ];

my @modules = __PACKAGE__->plugins;
require_ok( $_ ) for sort @modules;

done_testing;

