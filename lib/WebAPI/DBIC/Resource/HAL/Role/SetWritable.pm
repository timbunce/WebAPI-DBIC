package WebAPI::DBIC::Resource::HAL::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::SetWritable - methods handling HAL requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

Supports the C<application/hal+json> and C<application/json> content types.

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
            return $self->serializer->set_from_json($self->request->content);
        },
    };
    return $types;
};


1;
