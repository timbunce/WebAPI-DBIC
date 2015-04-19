package WebAPI::DBIC::Resource::JSONAPI::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::Set - add JSON API content type support for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/vnd.api+json> content type.

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::JSONAPI;

use Carp qw(confess);

requires '_build_content_types_provided';
requires 'encode_json';
requires 'set';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/vnd.api+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->to_json_as_jsonapi;
        }
    };
    return $types;
};


sub to_json_as_jsonapi {
    my $self = shift;

    return $self->encode_json( $self->serializer->render_jsonapi_response() );
}


1;
