requires 'Carp';
requires 'DBIx::Class';
requires 'HTTP::Throwable';
requires 'HTTP::Headers::ActionPack';
requires 'JSON::MaybeXS';
requires 'List::Util';
requires 'Module::Runtime';
requires 'Moo';
requires 'namespace::clean';
requires 'parent';
requires 'Path::Router';
requires 'Plack';
requires 'Plack::App::File';
requires 'Plack::App::Path::Router';
requires 'Scalar::Util';
requires 'Sub::Exporter';
requires 'Sub::Quote';
requires 'Try::Tiny';
requires 'URI';
requires 'Web::Machine';
requires 'Data::Dumper::Concise'; # for Dwarn

on test => sub {
   requires 'DBIx::Class';
   requires 'Module::Pluggable';
   requires 'Sort::Key';
   requires 'Test::DBIx::Class';
   requires 'Test::HTTP::Response';
   requires 'Test::More' => '0.98';
   requires 'Test::Most';
   requires 'Test::Roo';
   requires 'Test::Pod';
   requires 'Test::Compile';
};
