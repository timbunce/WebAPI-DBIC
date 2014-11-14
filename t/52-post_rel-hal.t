#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok qw/basic/;

subtest "===== Create item, with embedded items, by POST to set =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    my $track_with_embedded_cd = {
        title => "Just One More",
        position => 42,
        _embedded => {
            disc => {
                artist => 1,
                title => 'The New New',
                year => '2014',
                genreid => 1,
            }
        }
    };

    my $item;

    test_psgi $app, sub { # create, with embedded, only location returned
        my $res = shift->(dsreq_hal( POST => "/track?rollback=1", [], $track_with_embedded_cd));
        my ($location, $data) = dsresp_created_ok($res);
        like $location, qr{^/track/\d+$}, 'returns reasonable Location';
        is $data, undef, 'returns no data'
            or diag $data;
        # TODO should GET the returned location to check it
    };


    test_psgi $app, sub { # create, with embedded, return self
        my $res = shift->(dsreq_hal( POST => "/track?rollback=1&prefetch=self", [], $track_with_embedded_cd));
        my ($location, $track) = dsresp_created_ok($res);
        like $location, qr{^/track/\d+$}, 'returns reasonable Location';

        is ref $track, 'HASH', 'return data';
        ok $track->{trackid}, 'has trackid assigned';
        is $track->{title}, $track_with_embedded_cd->{title};
        is $track->{position}, $track_with_embedded_cd->{position};
        ok $track->{cd}, 'has cd assigned';

        ok !exists $track->{_embedded}, 'has no _embedded';
    };


    test_psgi $app, sub { # create, with embedded, return self and disc
        my $res = shift->(dsreq_hal( POST => "/track?rollback=1&prefetch=self,disc", [], $track_with_embedded_cd));
        my ($location, $track) = dsresp_created_ok($res);
        like $location, qr{^/track/\d+$}, 'returns reasonable Location';

        is ref $track, 'HASH', 'return data';
        ok $track->{trackid}, 'has trackid assigned';
        is $track->{title}, $track_with_embedded_cd->{title};
        is $track->{position}, $track_with_embedded_cd->{position};
        ok $track->{cd}, 'has cd assigned';

        ok $track->{_embedded}, 'has _embedded';
        ok my $disc = $track->{_embedded}{disc};
        is ref $disc, 'HASH', 'has _embedded disc';
        is $disc->{id}, $track->{disc}, 'disc matches';
        is $disc->{name}, $track_with_embedded_cd->{_embedded}{disc}{name}, 'disc name matches';
    };
};

done_testing();
