package WebAPI::DBIC::Machine;

use Moo;
use Sub::Quote 'quote_sub';

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
