#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok qw/basic/;

subtest "===== GET distinct =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;


    test_psgi $app, sub {
        my $resp = shift->(dsreq_hal( GET => "/cd?fields=year&order=year&distinct=1" ));
        my $data = dsresp_ok($resp);
        my $set = has_hal_embedded_list($data, "cd", 4, 4);
        cmp_deeply($set, [ { year => 1997 }, { year => 1998 }, { year => 1999 }, { year => 2001 } ]);
    };

};

done_testing();
