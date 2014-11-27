BEGIN { unlink 'temp_test_db' } # remove old copy, if any
 {
  'schema_class' => 'TestSchema',
  'connect_info' => {
      dsn   => 'dbi:SQLite:dbname=temp_test_db',
  },
  'fixture_class' => '::TestFixtureCommand',
};

