package WebAPI::DBIC::Resource::ActiveModel::Role::Item;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::Item - methods related to handling requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

The response is intended to be compatible with the Ember Data ActiveModelAdapter
L<http://emberjs.com/api/data/classes/DS.ActiveModelAdapter.html>

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::ActiveModel;


requires '_build_content_types_provided';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->serializer->item_to_json($self->item);
        }
    };
    return $types;
};


1;
