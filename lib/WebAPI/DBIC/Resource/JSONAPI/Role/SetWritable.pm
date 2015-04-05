package WebAPI::DBIC::Resource::JSONAPI::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::SetWritable - methods handling JSON API requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

Supports the C<application/vnd.api+json> and C<application/json> content types.

=cut

use Moo::Role;

use Devel::Dwarn;
use Carp qw(confess);

use WebAPI::DBIC::Serializer::JSONAPI;


requires '_build_content_types_accepted';
requires 'render_item_into_body';
requires 'decode_json';
requires 'set';
requires 'prefetch';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/vnd.api+json' => 'from_jsonapi_json' };
    return $types;
};


sub from_jsonapi_json {
    my $self = shift;

    $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));

    my $item = $self->serializer->create_resource( $self->decode_json($self->request->content) );

    return $self->item($item);
}


1;
