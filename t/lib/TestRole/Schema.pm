package TestRole::Schema;

require Test::DBIx::Class;

use Moo::Role;

# We set DBNAME so the in-memory database isn't used
# (otherwise tests would fail because DBICAuth reconnects to the db
# so the original connection is closed and the db data would be lost)
$ENV{DBNAME} = "temp-test-db";

has schema_config => (is => 'ro', lazy => 1, builder => 1);
sub _build_schema_config {
    my ($self) = @_;
    return {
        schema_class => 'TestSchema',
    },
}


has schema => (is => 'ro', lazy => 1, builder => 1, handles => ['resultset']);
sub _build_schema {
    my ($self) = @_;
    Test::DBIx::Class->import($self->schema_config, qw(Schema reset_schema));
    return Schema();
}


has fixtures => (is => 'ro', lazy => 1, builder => 1);
sub _build_fixtures {
    return {
        basic => sub {
            my ($self) = @_;


            $self->schema->populate('Genre', [
                [qw/genreid name/],
                [qw/1       emo  /],
                [qw/2       country/],
                [qw/3       pop/],
                [qw/4       goth/],
            ]);

            $self->schema->populate('Artist', [
                [ qw/artistid name/ ],
                [ 1, 'Caterwauler McCrae' ],
                [ 2, 'Random Boy Band' ],
                [ 3, 'We Are Goth' ],
                [ 4, 'KielbaSka' ],
                [ 5, 'Gruntfiddle' ],
                [ 6, 'A-ha Na Na' ],
            ]);

            $self->schema->populate('CD', [
                [ qw/cdid artist title year genreid/ ],
                [ 1, 1, "Spoonful of bees", 1999, 1, ],
                [ 2, 1, "Forkful of bees", 2001, 2, ],
                [ 3, 1, "Caterwaulin' Blues", 1997, 2, ],
                [ 4, 2, "Generic Manufactured Singles", 2001, 3, ],
                [ 5, 3, "Come Be Depressed With Us", 1998, 4, ],
            ]);

            $self->schema->populate('Producer', [
                [ qw/producerid name/ ],
                [ 1, 'Matt S Trout' ],
                [ 2, 'Bob The Builder' ],
                [ 3, 'Fred The Phenotype' ],
            ]);

            $self->schema->populate('CD_to_Producer', [
                [ qw/cd producer/ ],
                [ 1, 1 ],
                [ 1, 2 ],
                [ 1, 3 ],
            ]);

            $self->schema->populate('Track', [
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
            ]);

            $self->schema->populate('Gig' => [
                [qw/artistid gig_datetime/],
                [1, '2014-01-01T01:01:01Z' ],
                [2, '2014-06-30T19:00:00Z' ],
                [3, '2014-06-30T13:00:00Z' ],
            ]);
        },
    };
}


=head3 add_fixture( $fixture_name, $code )

Add a new fixture definition to the internal fixtures
dictionary. C<$code> will receive C<$self> as its only argument.

=head3 load_fixtures( @fixture_names )

Run the fixture code found in C<< $self->fixtures >> for each name in
C<@fixture_names>.  Fixtures are run in passed order.

=head3 reset_fixtures()

Wipe the schema;

=cut

sub add_fixture {
    my ($self, $key, $code) = @_;
    $self->fixtures->{$key} = $code;
}

sub load_fixtures {
    my ($self, @fixtures) = @_;

    for my $fixture (@fixtures) {
        my $fixture_sub = $self->fixtures->{$fixture}
            or die "No such fixture set: $fixture";
        $fixture_sub->($self);
    }

    return;
}

sub reset_fixtures { reset_schema() }


1;
__END__
