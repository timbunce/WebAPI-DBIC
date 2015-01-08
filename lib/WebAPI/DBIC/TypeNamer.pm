package WebAPI::DBIC::TypeNamer;

use Moo;

use String::CamelCase qw(camelize decamelize);
use Lingua::EN::Inflect::Number qw(to_S to_PL);
use Carp qw(croak confess);
use Devel::Dwarn;

use namespace::clean -except => [qw(meta)];
use MooX::StrictConstructor;


# specify what information should be used to define the url path/type of a schema class
# (result_name is deprecated and only supported for backwards compatibility)
has type_name_from  => (is => 'ro', default => 'source_name'); # 'source_name', 'result_name'

# how type_name_from should be inflected
has type_name_inflect => (is => 'ro', default => 'original'); # 'original', 'singular', 'plural'

# how type_name_from should be capitalized
has type_name_style => (is => 'ro', default => 'under_score'); # 'original', 'CamelCase', 'camelCase', 'under_score'


sub type_name_for_resultset {
    my ($self, $rs) = @_;

    my $type_name;
    if ($self->type_name_from eq 'source_name') {
        $type_name = $rs->result_source->source_name;
    }
    elsif ($self->type_name_from eq 'result_name') { # deprecated
        $type_name = $rs->name; # eg table name
        $type_name = $$type_name if ref($type_name) eq 'SCALAR';
    }
    else {
        confess "Invalid type_name_from: ".$self->type_name_from;
    }

    return $self->_inflect_and_style($type_name);
}


sub type_name_for_result_class {
    my ($self, $result_class) = @_;

    confess "bad type_name_from"
        unless $self->type_name_from eq 'source_name';

    (my $type_name = $result_class) =~ s/^.*:://;

    return $self->_inflect_and_style($type_name);
}


sub _inflect_and_style {
    my ($self, $type_name) = @_;

    if ($self->type_name_inflect eq 'singular') {
        $type_name = to_S($type_name);
    }
    elsif ($self->type_name_inflect eq 'plural') {
        $type_name = to_PL($type_name);
    }
    else {
        confess "Invalid type_name_inflect: ".$self->type_name_inflect
            unless $self->type_name_inflect eq 'original';
    }

    if ($self->type_name_style eq 'under_score') {
        $type_name = decamelize($type_name);
    }
    elsif ($self->type_name_style eq 'CamelCase') {
        $type_name = camelize($type_name);
    }
    elsif ($self->type_name_style eq 'camelCase') {
        $type_name = lcfirst(camelize($type_name));
    }
    else {
        confess "Invalid type_name_style: ".$self->type_name_from
            unless $self->type_name_style eq 'original';
    }

    return $type_name;
}


1;
