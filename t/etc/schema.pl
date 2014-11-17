BEGIN { unlink 'temp_test_db' } # remove old copy, if any
 {
  'schema_class' => 'TestSchema',
  'connect_info' => {
      dsn   => 'dbi:SQLite:dbname=temp_test_db',
  },
  'fixture_sets' => {
    'basic' => [
      'Genre' =>  [
        [qw/genreid name/],
        [qw/1       emo  /],
        [qw/2       country/],
        [qw/3       pop/],
        [qw/4       goth/],
      ],
      'Artist' => [
        [ qw/artistid name/ ],
        [ 1, 'Caterwauler McCrae' ],
        [ 2, 'Random Boy Band' ],
        [ 3, 'We Are Goth' ],
        [ 4, 'KielbaSka' ],
        [ 5, 'Gruntfiddle' ],
        [ 6, 'A-ha Na Na' ],
      ],
      'CD' => [
        [ qw/cdid artist title year genreid/ ],
        [ 1, 1, "Spoonful of bees", 1999, 1, ],
        [ 2, 1, "Forkful of bees", 2001, 2, ],
        [ 3, 1, "Caterwaulin' Blues", 1997, 2, ],
        [ 4, 2, "Generic Manufactured Singles", 2001, 3, ],
        [ 5, 3, "Come Be Depressed With Us", 1998, 4, ],
      ],
      'Producer' => [
        [ qw/producerid name/ ],
        [ 1, 'Matt S Trout' ],
        [ 2, 'Bob The Builder' ],
        [ 3, 'Fred The Phenotype' ],
      ],
      'CD_to_Producer' => [
        [ qw/cd producer/ ],
        [ 1, 1 ],
        [ 1, 2 ],
        [ 1, 3 ],
      ],
      'Track' => [
        [ qw/trackid cd  position title/ ],
        [ 4, 2, 1, "Stung with Success"],
        [ 5, 2, 2, "Stripy"],
        [ 6, 2, 3, "Sticky Honey"],
        [ 7, 3, 1, "Yowlin"],
        [ 8, 3, 2, "Howlin"],
        [ 9, 3, 3, "Fowlin"],
        [ 10, 4, 1, "Boring Name"],
        [ 11, 4, 2, "Boring Song"],
        [ 12, 4, 3, "No More Ideas"],
        [ 13, 5, 1, "Sad"],
        [ 14, 5, 2, "Under The Weather"],
        [ 15, 5, 3, "Suicidal"],
        [ 16, 1, 1, "The Bees Knees"],
        [ 17, 1, 2, "Apiary"],
        [ 18, 1, 3, "Beehind You"],
      ],
      'Gig' => [
        [qw/artistid gig_datetime/],
        [1, '2014-01-01T01:01:01Z' ],
        [2, '2014-06-30T19:00:00Z' ],
        [3, '2014-06-30T13:00:00Z' ],
      ],
    ]
  },
};
