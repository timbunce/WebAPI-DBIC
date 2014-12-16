# https://metacpan.org/pod/distribution/Module-CPANfile/lib/cpanfile.pod

requires 'perl', '5.010';

requires 'DBIx::Class', '0.08250'; # https://github.com/timbunce/WebAPI-DBIC/issues/14
requires 'SQL::Translator', '0.11018';

requires 'Web::Machine', '0.15';

requires 'Path::Router', '0.13';

requires 'DBD::SQLite', '1.46';
requires 'HTTP::Throwable';
requires 'HTTP::Headers::ActionPack';
requires 'JSON::MaybeXS';
requires 'List::Util';
requires 'Module::Runtime';
requires 'Moo', '1.001000';
requires 'namespace::clean';
requires 'parent';
requires 'Plack', '1.0033';
requires 'Plack::App::File';
requires 'Plack::App::Path::Router', '0.06';
requires 'Scalar::Util';
requires 'String::CamelCase';
requires 'Sub::Exporter';
requires 'Sub::Quote';
requires 'Sub::Util';
requires 'Try::Tiny';
requires 'URI';
requires 'Lingua::EN::Inflect::Number', '1.11';
requires 'Lingua::EN::Inflect', '1.894'; # recent for predictable behaviour
requires 'Data::Dumper::Concise'; # for Dwarn
requires 'Alien::Web::HalBrowser';

on test => sub {
   requires 'autodie';
   requires 'Module::Pluggable';
   requires 'Sort::Key';
   requires 'Test::DBIx::Class', '0.43';
   requires 'Test::HTTP::Response';
   requires 'Test::More' => '0.98';
   requires 'Test::Most';
   requires 'Test::Pod';
   requires 'Test::Compile', 'v1.1.0';
   requires 'ToolSet';
   requires 'Data::Printer';
   requires 'DBIx::Class::Fixtures', '1.001025';
   requires 'Cpanel::JSON::XS', '>= 3.0110, != 3.0112'; # https://github.com/timbunce/WebAPI-DBIC/issues/21
};
