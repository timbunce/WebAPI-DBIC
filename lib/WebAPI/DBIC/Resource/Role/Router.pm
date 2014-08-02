package WebAPI::DBIC::Resource::Role::Router;

use Moo::Role;

# Currently we assume use of Path::Router - we should allow others to be used

# Uses the router to find the route that matches the given parameter hash
# returns nothing if there's no match, else
# returns the absolute url in scalar context, or in list context it returns
# the prefix (SCRIPT_NAME) and the relative url (from the router)
# Should probably be broken out into separate methods
sub uri_for { ## no critic (RequireArgUnpacking)
    my $self = shift; # %pk in @_

    my $env = $self->request->env;
    my $router = $env->{'plack.router'};
    my $url = $router->uri_for(@_)
        or return;

    my $prefix = $env->{SCRIPT_NAME};
    return "$prefix/$url" unless wantarray;
    return ($prefix, $url);
}


1;
