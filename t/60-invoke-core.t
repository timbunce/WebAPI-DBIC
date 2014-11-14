#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok qw/basic/;

subtest "===== Invoke =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    my $item;

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/1/invoke/get_column", [], {
            args => [ 'name' ]
        }));
        my $data = dsresp_ok($res);
        is_deeply $data, { result => "Caterwauler McCrae" }, 'returns expected data'
            or diag $data;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/1/invoke/get_column", [], {
            args => {}
        }));
        dsresp_ok($res, 400);
        like $res->content, qr/args must be an array/i;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/1/invoke/get_column", [], {
            nonesuch => 1
        }));
        dsresp_ok($res, 400);
        like $res->content, qr/Unknown attributes: nonesuch/i;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/1/invoke/get_column", [], []));
        dsresp_ok($res, 400);
        like $res->content, qr/not a JSON hash/i;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/1/invoke/get_column", [], {
            args => [ 'nonesuch' ]
        }));
        dsresp_ok($res, 500); # XXX would be nice to avoid a 500 for this
    };

};

done_testing;
