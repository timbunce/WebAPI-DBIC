# https://metacpan.org/pod/distribution/Module-CPANfile/lib/cpanfile.pod
requires 'perl', '5.010';
requires 'Carp';
requires 'DBIx::Class';
requires 'HTTP::Throwable';
requires 'HTTP::Headers::ActionPack';
requires 'JSON::MaybeXS';
requires 'List::Util';
requires 'Module::Runtime';
requires 'Moo', '1.001000';
requires 'namespace::clean';
requires 'parent';
requires 'Path::Router', '0.13';
requires 'Plack', '1.0033';
requires 'Plack::App::File';
requires 'Plack::App::Path::Router', '0.06';
requires 'Scalar::Util';
requires 'Sub::Exporter';
requires 'Sub::Quote';
requires 'Try::Tiny';
requires 'URI';
requires 'Web::Machine', '0.15';
requires 'Data::Dumper::Concise'; # for Dwarn

on test => sub {
   requires 'Module::Pluggable';
   requires 'Sort::Key';
   requires 'Test::DBIx::Class';
   requires 'Test::HTTP::Response';
   requires 'Test::More' => '0.98';
   requires 'Test::Most';
   requires 'Test::Pod';
   requires 'Test::Compile', 'v1.1.0';
   requires 'ToolSet';
   requires 'Data::Printer';
};
