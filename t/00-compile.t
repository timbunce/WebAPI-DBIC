use strict;
use warnings;

use Test::Compile v1.1.0;

my $test = Test::Compile->new();
$test->all_files_ok('lib', 'blib');

my @psgi = <*.psgi>;
$test->ok(scalar @psgi, 'has psgi files');
$test->pl_file_compiles($_) for @psgi;

$test->done_testing();

