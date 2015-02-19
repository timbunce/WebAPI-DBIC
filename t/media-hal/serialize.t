use lib 't/lib';
use TestKit;
use DDP;

fixtures_ok [qw/basic/];

use Path::Router;

my $router = Path::Router->new();
$router->add_route(
    '/cd/:1' => (
        defaults => {
            result_class => Schema->resultset('CD')->result_source->result_class,
        },
    ),
);
$router->add_route(
    '/artist/:1' => (
        defaults => {
            result_class => Schema->resultset('Artist')->result_source->result_class,
        }
    ),
);
$router->add_route(
    '/genre/:1' => (
        defaults =>{
            result_class => Schema->resultset('Genre')->result_source->result_class,
        }
    )
);

use WebAPI::DBIC::Serializer::HAL;
my $serializer = WebAPI::DBIC::Serializer::HAL->new(router => $router);


subtest "====== HAL Serialize Item ========" => sub {
    my $hal_hash = $serializer->to_hal(
        Schema->resultset('CD')->find(
            {cdid => 1}
        )
    );

    my $expected = {
        artist       => 1,
        cdid         => 1,
        genreid      => 1,
        title        => 'Spoonful of bees',
        year         => 1999,
        single_track => undef,
        _links       => {
            artist   => {
                href => '/artist/1',
            },
            cd_to_producer => {
                href => '/cd_to_producer?me.cd_id=1',
            },
            genre => {
                href => '/genre/1',
            },
            self => {
                href => '/cd/1',
            },
            tracks => {
                href => '/track?me.cd=1',
            },
        },
    };

    is_deeply($hal_hash => $expected, 'Data matched expected format') || p $hal_hash;
};

subtest '========== HAL Serialize Item - Prefetch Artist, Genre ==========' => sub {
    my $hal_hash = $serializer->to_hal(
        Schema->resultset('CD')->find(
            {cdid => 1},
            {
                prefetch => ['artist', 'genre'],
            },
        ),
    );

    my $expected = {
        artist       => 1,
        cdid         => 1,
        genreid      => 1,
        title        => 'Spoonful of bees',
        year         => 1999,
        single_track => undef,
        _embedded    => {
            artist => {
                _links => {
                    self => {
                        href => '/artist/1',
                    },
                    cds => {
                        href => '/cd?me.artistid=1',
                    },
                    gigs => {
                        href => '/gig?me.artistid=1',
                    }
                },
                artistid => 1,
                rank     => 13,
                name     => 'Caterwauler McCrae',
                charfield => undef,
            },
            genre => {
                _links => {
                    self => {
                        href => '/genre/1',
                    },
                },
                genreid => 1,
                name    => 'emo',
            },
        },
        _links       => {
            artist   => {
                href => '/artist/1',
            },
            cd_to_producer => {
                href => '/cd_to_producer?me.cd_id=1',
            },
            genre => {
                href => '/genre/1',
            },
            self => {
                href => '/cd/1',
            },
            tracks => {
                href => '/track?me.cd=1',
            },
        },
    };

    is_deeply($hal_hash => $expected, 'Returned matched expected result') || p $hal_hash;
};

subtest '========== HAL Serialize Set ============' => sub {
    my $hal_hash = $serializer->to_hal(
        Schema->resultset('Artist')->search_rs({}, {prefetch => 'cds'}),
    );

    my $expected = {_embedded => {
        artist => [
            {
                artistid    => 1,
                charfield   => undef,
                name        => 'Caterwauler McCrae',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/1',
                    },
                    cds => {
                        href => '/cd?me.artist_id=1',
                    },
                },
            },
            {
                artistid    => 2,
                charfield   => undef,
                name        => 'Random Boy Band',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/2',
                    },
                    cds => {
                        href => '/cd?me.artist_id=2',
                    },
                },
            },
            {
                artistid    => 3,
                charfield   => undef,
                name        => 'We Are Goth',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/3',
                    },
                    cds => {
                        href => '/cd?me.artist_id=3',
                    },
                },
            },
            {
                artistid    => 4,
                charfield   => undef,
                name        => 'KielbaSka',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/4',
                    },
                    cds => {
                        href => '/cd?me.artist_id=4',
                    },
                },
            },
            {
                artistid    => 5,
                charfield   => undef,
                name        => 'Gruntfiddle',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/5',
                    },
                    cds => {
                        href => '/cd?me.artist_id=5',
                    },
                },
            },
            {
                artistid    => 6,
                charfield   => undef,
                name        => 'A-ha Na Na',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/6',
                    },
                    cds => {
                        href => '/cd?me.artist_id=6',
                    },
                },
            },
        ]
    }};

    is_deeply($hal_hash => $expected, 'Returned matched expected result') || p $hal_hash;
};

subtest '========= HAL Serialize Set - Prefetch CDs ==========' => sub {
    my $hal_hash = $serializer->to_hal(
        Schema->resultset('Artist')->search_rs({}, {prefetch => 'cds'}),
    );

    my $expected = {_embedded => {
        artist => [
            {
                artistid    => 1,
                charfield   => undef,
                name        => 'Caterwauler McCrae',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/1',
                    },
                    cds => {
                        href => '/cd?me.artist_id=1',
                    },
                },
            },
            {
                artistid    => 2,
                charfield   => undef,
                name        => 'Random Boy Band',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/2',
                    },
                    cds => {
                        href => '/cd?me.artist_id=2',
                    },
                },
            },
            {
                artistid    => 3,
                charfield   => undef,
                name        => 'We Are Goth',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/3',
                    },
                    cds => {
                        href => '/cd?me.artist_id=3',
                    },
                },
            },
            {
                artistid    => 4,
                charfield   => undef,
                name        => 'KielbaSka',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/4',
                    },
                    cds => {
                        href => '/cd?me.artist_id=4',
                    },
                },
            },
            {
                artistid    => 5,
                charfield   => undef,
                name        => 'Gruntfiddle',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/5',
                    },
                    cds => {
                        href => '/cd?me.artist_id=5',
                    },
                },
            },
            {
                artistid    => 6,
                charfield   => undef,
                name        => 'A-ha Na Na',
                rank        => 13,
                _links      => {
                    self => {
                        href => '/artist/6',
                    },
                    cds => {
                        href => '/cd?me.artist_id=6',
                    },
                },
            },
        ]
    }};

    is_deeply($hal_hash => $expected, 'Returned matched expected result') || p $hal_hash;
};

done_testing;
