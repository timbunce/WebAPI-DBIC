package WebAPI::DBIC::Resource::Role::DBICException;

use Carp qw(croak confess);
use Scalar::Util qw(blessed);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'response';


sub finish_request {
    my ($self, $metadata) = @_;

    return $self->handle_web_machine_exception($metadata->{exception});
}


# XXX we probably ought to allow a stck/list of handlers that can try to
# recognise an exception - we'd try them in turn, perhaps until one has
# converted it into an object that has an as_psgi method.

sub handle_web_machine_exception {
    my ($self, $exception) = @_;

    return unless $exception;

    #warn "$exception";

    if (blessed($exception) && $exception->can('as_psgi')) {
        my ($status, $headers, $body) = @{ $exception->as_psgi };
        $self->response->status($status);
        $self->response->headers($headers);
        $self->response->body($body);
        return;
    }

    #$exception->rethrow if ref $exception and $exception->can('rethrow');
    #die $exception if ref $exception;

    (my $line1 = $exception) =~ s/\n.*//ms;

    my $error_data;
    # ... DBD::Pg::st execute failed: ERROR:  column "nonesuch" does not exist
    if ($exception =~ m/DBD::.*? \s+ failed:.*? \s+ column:? \s+ "?(.*?)"? \s+ (.*)/x) {
        $error_data = {
            status => 400,
            field => $1,
            foo => "$1: $2",
        };
    }
    # handle exceptions from Params::Validate
    elsif ($exception =~ /The \s '(\w+)' \s parameter \s \(.*?\) \s to \s (\S+) \s did \s not \s pass/x) {
        $error_data = {
            status => 400,
            field => $1,
            message => $line1,
        };
    }

    warn "Exception: $line1 (@{[ %{ $error_data||{} } ]})\n"
        if $ENV{WEBAPI_DBIC_DEBUG};

    if ($error_data) { # we recognized the exception

        $error_data->{status} ||= 500;

        # only include detailed exception information if not in production
        # (as it might contain sensitive information)
        $error_data->{_embedded}{exceptions}[0]{exception} = "$exception" # stringify
            if $ENV{PLACK_ENV} ne 'production';

        # create response
        # XXX would be nice to create an exception object that can as_psgi()
        # then reuse the handling of that above
        my $json = JSON->new->ascii->pretty;
        my $response = $self->response;
        $response->status($error_data->{status});
        my $body = $json->encode($error_data);
        $response->body($body);
        $response->content_length(length $body);
        $response->content_type('application/hal+json');
    }
    else {
        warn "Exception: $line1\n"
    }

    return;
}


1;
