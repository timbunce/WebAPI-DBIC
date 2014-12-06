package Test::DBIx::Class::FixtureCommand::TestFixtureCommand;

use Moose;
use DBIx::Class::Fixtures;

with 'Test::DBIx::Class::Role::FixtureCommand';

sub install_fixtures {
    my ($self, $sets, @rest) = @_;

    my @sets = ref($sets) ? @$sets : ($sets, @rest);
    my $schema = $self->schema_manager->schema;
    my $fixtures = DBIx::Class::Fixtures->new({config_dir => 't/etc/fixtures', debug => 6});
    for my $set (@sets){
        $fixtures->populate({no_deploy => 1, schema => $schema, directory => "t/etc/fixtures/$set"});
    }
}

__PACKAGE__->meta->make_immutable;
1;
