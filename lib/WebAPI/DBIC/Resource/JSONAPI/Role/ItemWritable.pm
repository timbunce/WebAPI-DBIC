package WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable - methods handling JSON API requests to update item resources

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::JSONAPI;

requires 'serializer';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/vnd.api+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        },
    };
    return $types;
};


1;
