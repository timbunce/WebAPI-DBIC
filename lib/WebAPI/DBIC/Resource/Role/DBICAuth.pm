package WebAPI::DBIC::Resource::Role::DBICAuth;

use Moo::Role;
use Carp qw(confess);
use Try::Tiny;

use WebAPI::DBIC::Util qw(create_header);

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
    if ($http_auth_type =~ /^none/i) {
        # This role was included in the resource, so auth was desired, yet auth
        # has been disabled. That seems worthy of a warning.
        my $name = $self->set->result_source->result_class; # XXX the path would be better
        warn "HTTP authentication configured but disabled for $name\n"
            unless our $warn_once->{"http_auth_type $name"}++;
        return 1
    }
    elsif ($http_auth_type =~ /^basic/i) {

        my $auth_realm = $self->set->result_source->schema->storage->connect_info->[0] # dsn
            or die "panic: no dsn set";

        if ( $auth_header ) {
            return 1 if $self->connect_schema_as($auth_header->username, $auth_header->password);
        }
        return create_header( 'WWWAuthenticate' => [ 'Basic' => ( realm => $auth_realm ) ] );
    }
    else {
        die "Unsupported value for http_auth_type: $http_auth_type";
    }

}


1;
