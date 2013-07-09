package WebAPI::DBIC::Role::JsonParams;

# provides a param() method that returns query parameters
# except that any parameters named foo~json have their values
# JSON decoded, so they can be arbitrary data structures.

use Moo::Role;

use Carp qw(croak);
use JSON ();


requires 'request';

my $json = JSON->new->allow_nonref;


has parameters => (
    is => 'rw',
    lazy => 1,
    builder => '_build_parameters',
);

sub _build_parameters {
    my $self = shift;
    return $self->decode_rich_parameters($self->request->query_parameters);
}


sub param { ## no critic (RequireArgUnpacking)
    my $self = shift;

    return keys %{ $self->parameters } if @_ == 0;

    my $key = shift;
    return $self->parameters->{$key} unless wantarray;
    return $self->parameters->get_all($key);
}


sub decode_rich_parameters { # perhaps should live in a util library and be imported
    my ($class, $raw_params) = @_;

    # Note that this is transparent to duplicate query parameter names
    # i.e., foo=7&foo=8&foo~json=9 will result in the same set of duplicate
    # parameters as if the parameters were foo=7&foo=8&foo=9

    my @params;
    for my $key_raw (keys %$raw_params) {

        # parameter names with a ~json suffix have JSON encoded values
        my $is_json;
        (my $key_base = $key_raw) =~ s/~json$//
            and $is_json = 1;

        for my $v ($raw_params->get_all($key_raw)) {
            $v = $json->decode($v) if $is_json;
            push @params, $key_base, $v;
        }
    }

    return Hash::MultiValue->new(@params);
}



1;
