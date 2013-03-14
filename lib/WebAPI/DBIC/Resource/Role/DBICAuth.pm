package WebAPI::DBIC::Resource::Role::DBICAuth;

use Moo::Role;

use WebAPI::DBIC::Util qw(create_header);

requires 'set';
requires 'item';

sub _fmt_schema {
    my $schema = shift;
    no warnings;
    join ", ", map { "$_ => $schema->{$_}" } sort keys %$schema;
}

sub _schema {
    my $self = shift;
    my ($schema, $alt) = map { $_ ? $_->result_source->schema : () } ($self->set, $self->item);
    if ($alt and $alt != $schema) {
        $self->request->env->{'psgix.harakiri.commit'} = 1;
        warn $schema->storage->dbh;
        warn $alt->storage->dbh;
        die sprintf "$$ assert: set and item have different schema\n%s\n%s",
            _fmt_schema($schema), _fmt_schema($alt);
    }
    return $schema;
}


sub connect_schema_as {
    my ($self, $user, $pass) = @_;
    $_[2] = '...'; # hide password from stack trace

    my $schema = $self->_schema;
    my $ci = $schema->storage->connect_info;
    my ($ci_dsn, $ci_user, $ci_pass, $ci_attr) = @$ci;
    die "assert: expected attr as 3rd element in connect_info"
        unless ref $ci_attr eq 'HASH';

    # ok if we're currently using the right auth
    return 1 if $user eq $ci_user and $pass eq $ci_pass;

    # try to connect with the user supplied credentials
    my $newschema = $schema->clone->connect($ci_dsn, $user, $pass, $ci_attr);
    return 0 if not eval { $newschema->storage->dbh };

    # we connected ok, so update resultsets to use new connection
    for my $rs ($self->set, $self->item) {
        next unless $rs;
        $rs->result_source->schema($newschema);
    }
    return 1;
}


sub is_authorized {
    my ($self, $auth_header) = @_;
    if ( $auth_header ) {
        return 1 if $self->connect_schema_as($auth_header->username, $auth_header->password);
    }
    my $auth_realm = $self->_schema->storage->connect_info->[0]; # dsn
    return create_header( 'WWWAuthenticate' => [ 'Basic' => ( realm => $auth_realm ) ] );
}


1;
