package WebAPI::DBIC::Resource::Role::ItemInvoke;

use Moo::Role;

use Scalar::Util qw(blessed);

requires 'decode_json';
requires 'encode_json';
requires 'render_item_as_plain';
requires 'throwable';
requires 'item';

has method => (
   is => 'ro',
   required => 1,
);

sub post_is_create { return 0 }

around 'allowed_methods' => sub {
   return [ qw(POST) ];
};


sub process_post {
    my $self = shift;

    # Here's we're calling a method on the item as a simple generic behaviour.
    # This is very limited because, for example, the method has no knowledge
    # that it's being called inside a web service, thus no way to do redirects
    # or provide HTTP specific rich-exceptions.
    # If anything more sophisticated is required then it should be implemented
    # as a specific resource class for the method (or perhaps a role if there's
    # a set of methods that require similar behaviour).

    # The POST body content provides a data structure containing the method arguments
    # { args => [ (@_) ] }
    $self->throwable->throw_bad_request(415, errors => "Request content-type not application/json")
        unless $self->request->header('Content-Type') =~ 'application/.*?json';
    my $invoke_body_data = $self->decode_json($self->request->content);
    $self->throwable->throw_bad_request(400, errors => "Request content not a JSON hash")
        unless ref $invoke_body_data eq 'HASH';

    my @method_args;
    if (my $args = delete $invoke_body_data->{args}) {
        $self->throwable->throw_bad_request(400, errors => "The args must be an array")
            if ref $args ne 'ARRAY';
        @method_args = @$args;
    }
    $self->throwable->throw_bad_request(400, errors => "Unknown attributes: @{[ keys %$invoke_body_data ]}")
        if keys %$invoke_body_data;

    my $method_name = $self->method;
    # the method is expected to throw an exception on error.
    my $result_raw = $self->item->$method_name(@method_args);

    my $result_rendered;
    # return a DBIC resultset as array of hashes of ALL records (no paging)
    if (blessed($result_raw) && $result_raw->isa('DBIx::Class::ResultSet')) {
        $result_rendered = [ map { $self->render_item_as_plain($_) } $result_raw->all ];
    }
    # return a DBIC result row as a hash
    elsif (blessed($result_raw) && $result_raw->isa('DBIx::Class::Row')) {
        $result_rendered = $self->render_item_as_plain($result_raw);
    }
    # return anything else as raw JSON wrapped in a hash
    else {
        # we shouldn't get an object here, but if we do then we
        # stringify it here to avoid exposing the guts
        $result_rendered = { result => (blessed $result_raw) ? "$result_raw" : $result_raw };
    }

    $self->response->body( $self->encode_json($result_rendered) );
    return 200;
}

1;
