package WebAPI::DBIC::Resource::Role::DBICAuth;

=head1 NAME

WebAPI::DBIC::Resource::Role::DBICAuth - methods for authentication and authorization

=cut

use Carp qw(confess);
use Try::Tiny;

use WebAPI::DBIC::Util qw(create_header);

use Moo::Role;


requires 'set';
requires 'http_auth_type';

sub connect_schema_as { # XXX sub rather than method?
    my ($self, $user, $pass) = @_;
    $_[2] = '...'; # hide password from stack trace

    my $schema = $self->set->result_source->schema;
    my $ci = $schema->storage->connect_info;
    my ($ci_dsn, $ci_user, $ci_pass, $ci_attr) = @$ci;

    # ok if we're currently using the right auth
    return 1 if defined $ci_user and $user eq $ci_user
            and defined $ci_pass and $pass eq $ci_pass;

    # try to connect with the user supplied credentials
    my $newschema = $schema->clone->connect($ci_dsn, $user, $pass, $ci_attr);
    my $err;
    try { $newschema->storage->dbh }
    catch {
        # XXX we need to differentiate between auth errors and other problems
        warn "Error connecting to $ci_dsn: $_\n";
        $err = $_;
    };
    return 0 if $err;

    # we connected ok, so update resultset to use new connection
    # XXX Is this sane and safe?
    $self->set->result_source->schema($newschema);

    return 1;
}


sub is_authorized {
    my ($self, $auth_header) = @_;

    my $http_auth_type = $self->http_auth_type || '';
    if ($http_auth_type =~ /^(none|disabled)$/) {
        # This role was included in the resource, so auth was desired, yet auth
        # has been specified. That seems worthy of a warning.
        # 'none' gives a warning, but 'disabled' is silent.
        (my $name = $self->request->path) =~ s:/\d+$::;
        warn "HTTP authentication configured but not enabled for $name\n"
            if $http_auth_type ne 'disabled'
            and not our $warn_once->{"http_auth_type $name"}++;
        return 1
    }
    elsif ($http_auth_type eq 'Basic') {

        # https://metacpan.org/pod/DBIx::Class::Storage::DBI#connect_info
        my $ci = $self->set->result_source->schema->storage->connect_info;
        # extract the dsn (doesn't handle $ci->[0] being a code ref)
        my $dsn = (ref $ci->[0]) ? $ci->[0]->{dsn} : $ci->[0];
        confess "Can't determine DSN to use as auth realm from @$ci"
            if !$dsn or ref $dsn;

        my $auth_realm = "Insecure unless https! - $dsn"; # XXX get via a method
        if ( $auth_header ) {
            return 1 if $self->connect_schema_as($auth_header->username, $auth_header->password);
        }
        return create_header( 'WWWAuthenticate' => [ 'Basic' => ( realm => $auth_realm ) ] );
    }

    die "Unsupported value for http_auth_type: $http_auth_type";
}


1;
