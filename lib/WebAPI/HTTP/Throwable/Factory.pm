package WebAPI::HTTP::Throwable::Factory;

=head1 NAME

WebAPI::HTTP::Throwable::Factory - methods to support throwing HTTP exceptions

=head1 DESCRIPTION

Throw L<HTTP::Throwable> exceptions that contain JSON in the body.

See also L<WebAPI::HTTP::Throwable::Role::JSONBody>.

=cut

# I'm not sure what value there is here, but maybe I'm just forgetting the goodness.
# Exception handling probably needs to be rethought.
# See also WebAPI::HTTP::Throwable::Role::JSONBody

use strict;
use warnings;

use parent 'HTTP::Throwable::Factory';

use Carp qw(carp cluck);
use JSON::MaybeXS qw(JSON);


sub extra_roles {
    return (
        'WebAPI::HTTP::Throwable::Role::JSONBody', # remove HTTP::Throwable::Role::TextBody
        'StackTrace::Auto'
    );
}

sub throw_bad_request {
    my ($class, $status, %opts) = @_;

    cluck("bad status $status") unless $status =~ /^4\d\d$/;
    carp("throw_bad_request @_") if $ENV{WEBAPI_DBIC_DEBUG};

    # XXX TODO validations
    my $data = {
        errors => $opts{errors},
    };

    my $json_body = JSON->new->ascii->pretty->encode($data);

    # [ 'Content-Type' => 'application/hal+json' ],
    $class->throw( BadRequest => {
        status_code => $status,
        message => $json_body,
    });

    return;                     # not reached
}



1;
__END__
