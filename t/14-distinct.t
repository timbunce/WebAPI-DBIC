#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';


local $SIG{__DIE__} = \&Carp::confess;

after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};

test "===== GET distinct =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;


    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/cd?fields=year&order=year&distinct=1" )));
        my $set = is_set_with_embedded_key($data, "cd", 4, 4);
        for my $item (@$set) {
            is keys %$item, 1, 'has one element';
            ok exists $item->{year}, 'has status element';
        }
    };

};

run_me();
done_testing();
