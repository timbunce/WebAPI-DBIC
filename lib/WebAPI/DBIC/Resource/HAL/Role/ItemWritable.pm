package WebAPI::DBIC::Resource::HAL::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::ItemWritable - methods handling HAL requests to update item resources

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::HAL;

requires 'serializer';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/hal+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        },
    };
    return $types;
};


1;
