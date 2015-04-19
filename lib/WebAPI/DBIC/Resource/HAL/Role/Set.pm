package WebAPI::DBIC::Resource::HAL::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::Set - add HAL content type support for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/hal+json> content type.

=cut

use Moo::Role;

use Carp qw(confess);

use WebAPI::DBIC::Serializer::HAL;

requires '_build_content_types_provided';
requires 'encode_json';
requires 'set';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/hal+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->to_json_as_hal;
        },
    };
    return $types;
};


sub to_json_as_hal   {
    my $self = shift;

    return $self->encode_json($self->serializer->render_set_as_hal($self->set));
}


1;
