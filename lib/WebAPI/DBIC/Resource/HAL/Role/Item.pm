package WebAPI::DBIC::Resource::HAL::Role::Item;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::Item - methods related to handling HAL requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/hal+json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::HAL;

requires '_build_content_types_provided';
requires 'encode_json';
requires 'item';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/hal+json' => 'to_json_as_hal' };
    return $types;
};


sub to_json_as_hal {
    my $self = shift;

    $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));

    return $self->encode_json($self->serializer->render_item_as_hal_hash($self->item))
}

1;
