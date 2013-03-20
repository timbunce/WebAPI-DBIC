package WebAPI::DBIC::Resource::Role::RichParams;

use Moo::Role;

use Carp qw(croak);
use Devel::Dwarn;
use JSON;

has parameters => (
    is => 'rw',
    lazy => 1,
    builder => '_build_params',
);


sub param {
    my $self = shift;

    return keys %{ $self->parameters } if @_ == 0;

    my $key = shift;
    return $self->parameters->{$key} unless wantarray;
    return $self->parameters->get_all($key);
}


sub _build_params {
    my $self = shift;
    return $self->decode_rich_parameters($self->request->query_parameters);
}


sub decode_rich_parameters { # should live in a util library and be imported
    my ($class, $raw_params) = @_;

    my $json = JSON->new->allow_nonref;

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
