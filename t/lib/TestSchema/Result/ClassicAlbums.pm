package TestSchema::Result::ClassicAlbums;

use base qw/DBIx::Class::Core/;

__PACKAGE__->table_class('DBIx::Class::ResultSource::View');

__PACKAGE__->table('classic_albums');
__PACKAGE__->result_source_instance->is_virtual(1);
__PACKAGE__->result_source_instance->view_definition(<<EOF);
    SELECT artist.name as artist, cd.title, genre.name as genre,
           cd.year as release_year, cd.cdid FROM cd cd
        JOIN artist artist ON cd.artist = artist.artistid
        JOIN genre genre ON cd.genreid = genre.genreid
    WHERE cd.year < '2000' and cd.single_track IS NULL
EOF


__PACKAGE__->add_columns(
    artist => {
        data_type => 'text',
    },
    title => {
        data_type => 'varchar',
        size      => 100,
    },
    genre => {
        data_type => 'text',
    },
    release_year => {
        data_type => 'varchar',
        size      => 100,
    },
    cdid => {
        data_type       => 'integer',
        is_foreign_key  => 1,
    },
);

__PACKAGE__->set_primary_key('cdid');

__PACKAGE__->belongs_to(cd => 'TestSchema::Result::CD', 'cdid');

1;
