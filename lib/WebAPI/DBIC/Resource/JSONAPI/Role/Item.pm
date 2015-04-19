package WebAPI::DBIC::Resource::JSONAPI::Role::Item;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::Item - methods related to handling JSON API requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/vnd.api+json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::JSONAPI;


requires '_build_content_types_provided';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/vnd.api+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->serializer->item_to_json;
        },
    };
    return $types;
};


1;
