package WebAPI::DBIC::Machine;

=head1 NAME

WebAPI::DBIC::Machine - a subclass of Web::Machine for WebAPI::DBIC

=cut

use Sub::Quote 'quote_sub';

use Moo;
use namespace::clean;

extends 'Web::Machine';

has debris => (
   is => 'ro',
   default => quote_sub q{ {} },
);

sub create_resource {
    my ($self, $request) = @_;
    return $self->{'resource'}->new(
        request  => $request,
        response => $request->new_response,
        %{ $self->debris },
    );
}

1;
