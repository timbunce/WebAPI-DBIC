package WebAPI::HTTP::Throwable::Role::JSONBody;

use Moo::Role;

sub body { return shift->message }

sub body_headers {
    my ($self, $body) = @_;

    return [
        'Content-Type'   => 'application/json',
        'Content-Length' => length $body,
    ];
}

sub as_string { return shift->body }

1;

__END__


=pod

=head1 NAME

WebAPI::HTTP::Throwable::Role::JSONBody - an exception with a JSON body

=head1 OVERVIEW

When an HTTP::Throwable exception uses this role, its PSGI response
will have a C<application/json> content type and will send the
C<message> attribute as the response body.  C<message> should be a
valid JSON string.

=cut


