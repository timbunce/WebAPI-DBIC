package HTTP::Throwable::Role::JSONBody;

use Moose::Role;

sub body { $_[0]->message }

sub body_headers {
    my ($self, $body) = @_;

    return [
        'Content-Type'   => 'application/json',
        'Content-Length' => length $body,
    ];
}

sub as_string { $_[0]->body }

no Moose::Role;
1;



=pod

=head1 NAME

HTTP::Throwable::Role::JSONBody - an exception with a JSON body

=head1 VERSION

version 0.016

=head1 OVERVIEW

This is a very simple role, implementing the required C<as_string>, C<body>,
and C<body_headers> for L<HTTP::Throwable>.  In turn, it requires that a
C<text_body> method be provided.

When an HTTP::Throwable exception uses this role, its PSGI response will have a
C<application/json> content type and will send the result of calling its C<text_body>
method as the response body.  It will also stringify to the text body.

The role L<HTTP::Throwable::Role::BoringText> can be useful to provide a
C<text_body> method that issues the C<status_line> as the body.

=head1 AUTHORS

=over 4

=item *

Stevan Little <stevan.little@iinteractive.com>

=item *

Ricardo Signes <rjbs@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Infinity Interactive, Inc..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__
# ABSTRACT: an exception with a plaintext body

