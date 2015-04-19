package WebAPI::DBIC::Resource::HAL::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::SetWritable - methods handling HAL requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

Supports the C<application/hal+json> and C<application/json> content types.

=cut

use Devel::Dwarn;
use Carp qw(confess);

use Moo::Role;


requires '_build_content_types_accepted';
requires 'decode_json';
requires 'item';
requires 'serializer';
requires 'request';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/hal+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->from_hal_json;
        },
    };
    return $types;
};


sub from_hal_json {
    my $self = shift;

    my $item = $self->serializer->create_resources_from_hal( $self->decode_json($self->request->content) );

    return $self->item($item);
}

1;
