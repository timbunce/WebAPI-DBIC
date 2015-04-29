package WebAPI::DBIC::Resource::Role::Root;

=head1 NAME

WebAPI::DBIC::Resource::Role::Root - methods to handle requests for the root resource

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing the root resource, e.g. C</>.

=cut

use Moo::Role;


requires 'encode_json';


has content_types_accepted => (
    is => 'ro',
    required => 1,
);

has content_types_provided => (
    is => 'ro',
    required => 1,
);


around content_types_provided => sub {
    my $orig = shift;
    my $self = shift;
    return [
        @{ $orig->($self, @_) },
        { 'text/html' => 'root_to_html' } # provide redirect to HAL browser XXX hack
    ];
};


sub allowed_methods { return [ qw(GET HEAD) ] }

sub provide_to_response_content_type { # called via content_types_provided callback
    my $self = shift;
    return $self->serializer->root_to_json();
}


sub root_to_html {
    my $self = shift;
    my $path   = $self->request->env->{REQUEST_URI}; # "/clients/v1/";
    # XXX this location should not be hard-coded
    $self->response->header(Location => "browser/browser.html#$path");
    return \302;
}


sub root_to_json {
    my $self = shift;
    die ref($self)." hasn't defined a root_to_json method";
}


1;
