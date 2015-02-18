use lib 't/lib';
use TestKit;

fixtures_ok [qw/basic/];

use WebAPI::DBIC::Serializer::HAL;

subtest "====== HAL Serialize Item ========" => sub {
    my $serializer = WebAPI::DBIC::Serializer::HAL->new();

    my $hal_hash = $serializer->to_hal(Schema->resultset('CD')->search({cdid => 1, "artist.artistid" => 1}, {join => ["artist", "genre"], columns => ['me.artist', 'me.cdid', 'artist.name']}));
    my $expected_cd = {
        artist       => 1,
        cdid         => 1,
        genreid      => 1,
        title        => 'Spoonful of bees',
        year         => 1999,
        single_track => undef,
        _embedded    => {
            artist => {
                artistid => 1,
                rank     => 13,
                name     => 'Caterwauler McCrae',
                charfield => undef,
            },
            genre => {
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
    use DDP; p $hal_hash;
    is_deeply($hal_hash => $expected_cd, 'Data matched expected format');
};
