package WebAPI::DBIC::Resource::Role::DBICAuth;

use Moo::Role;

use WebAPI::DBIC::Util qw(create_header);

requires 'set';
requires 'item';

sub connect_schema_as {
    my ($self, $user, $pass) = @_;

    my ($schema, $alt) = map { $_ ? $_->result_source->schema : () } ($self->set, $self->item);
    die "assert: set and item have different schema"
        if $alt and $alt != $schema;

    use Devel::Dwarn;
    Dwarn my $ci = $schema->storage->connect_info;
    my ($ci_dsn, $ci_user, $ci_pass, $ci_attr) = @$ci;
    die "assert: expected attr as 3rd element in connect_info"
        unless ref $ci_attr eq 'HASH';
    #warn "($ci_dsn, $ci_user, $ci_pass, $ci_attr)";

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
    return create_header( 'WWWAuthenticate' => [ 'Basic' => ( realm => 'Webmachine' ) ] );
}


1;
