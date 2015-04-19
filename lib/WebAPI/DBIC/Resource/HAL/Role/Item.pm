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
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/hal+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->serializer->item_to_json;
        },
    };
    return $types;
};


1;
