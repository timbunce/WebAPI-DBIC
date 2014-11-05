#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use TestDS_HAL;
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
        my $resp = shift->(dsreq_hal( GET => "/cd?fields=year&order=year&distinct=1" ));
        my $data = dsresp_ok($resp);
        my $set = has_hal_embedded_list($data, "cd", 4, 4);
        cmp_deeply($set, [ { year => 1997 }, { year => 1998 }, { year => 1999 }, { year => 2001 } ]);
    };

};

run_me();
done_testing();
