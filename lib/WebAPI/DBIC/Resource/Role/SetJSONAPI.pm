package WebAPI::DBIC::Resource::Role::SetJSONAPI;

=head1 NAME

WebAPI::DBIC::Resource::Role::SetHAL - add JSON API content type support for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/vnd.api+json> content type.

=cut

use Moo::Role;

use Carp qw(confess);

requires '_build_content_types_provided';
requires 'encode_json';
requires 'set';
requires 'render_jsonapi_response';
requires 'jsonapi_type';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/vnd.api+json' => 'to_json_as_jsonapi' };
    return $types;
};


sub to_json_as_jsonapi {
    my $self = shift;
    return $self->encode_json( $self->render_jsonapi_response( $self->set ) );
}


1;
