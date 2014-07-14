requires 'Web::Machine';
requires 'HTTP::Throwable';

on test => sub {
   requires 'Test::HTTP::Response';
   requires 'Test::DBIx::Class';
   requires 'Plack::App::Path::Router';
};
