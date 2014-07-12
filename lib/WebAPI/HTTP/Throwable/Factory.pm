package WebAPI::HTTP::Throwable::Factory;

use parent 'HTTP::Throwable::Factory';
use Carp qw(carp cluck);
use JSON;

sub extra_roles {
    return (
        'WebAPI::HTTP::Throwable::Role::JSONBody', # remove HTTP::Throwable::Role::TextBody
        'StackTrace::Auto'
    );
}

sub throw_bad_request {
    my ($class, $status, %opts) = @_;
    cluck("bad status") unless $status =~ /^4\d\d$/;
    carp("throw_bad_request @_");

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
