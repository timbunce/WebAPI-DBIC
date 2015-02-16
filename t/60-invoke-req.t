#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

my $app = TestWebApp->new({
    routes => [
        {
            set => Schema->source('Artist'),
            invokeable_methods_on_item => [qw(get_column)],
            invokeable_methods_on_set  => [qw(count)],
        },
    ]
})->to_psgi_app;

subtest "===== Invoke on Item =====" => sub {
    my ($self) = @_;

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

subtest "===== Invoke on Set =====" => sub {
    my ($self) = @_;

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/invoke/count", [], {
        }));
        my $data = dsresp_ok($res);
        is_deeply $data, { result => "6" }, 'returns expected data'
            or diag $data;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/invoke/count", [], {
            args => {}
        }));
        dsresp_ok($res, 400);
        like $res->content, qr/args must be an array/i;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/invoke/count", [], {
            nonesuch => 1
        }));
        dsresp_ok($res, 400);
        like $res->content, qr/Unknown attributes: nonesuch/i;
    };

    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/artist/invoke/count", [], []));
        dsresp_ok($res, 400);
        like $res->content, qr/not a JSON hash/i;
    };

};

done_testing;
