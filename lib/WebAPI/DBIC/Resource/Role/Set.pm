package WebAPI::DBIC::Resource::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::Role::Set - methods related to handling requests for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/json> content type.

=cut

use Moo::Role;


requires 'encode_json';
requires 'serializer';


has content_types_provided => (
    is => 'lazy',
);

sub _build_content_types_provided {
    return [
    {
        'application/vnd.wapid+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::WAPID;
            $self->serializer(WebAPI::DBIC::Serializer::WAPID->new(resource => $self));
            return $self->serializer->set_to_json($self->set);
        },
    },
    {
        'application/json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::ActiveModel;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->serializer->set_to_json($self->set);
        },
    },
    {
        'application/hal+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::HAL;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->serializer->set_to_json($self->set);
        },
    },
    {
        'application/vnd.api+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::JSONAPI;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->serializer->set_to_json($self->set);
        }
    },

    ];
}

sub to_plain_json { return $_[0]->encode_json($_[0]->serializer->render_set_as_plain($_[0]->set)) }

sub allowed_methods { return [ qw(GET HEAD) ] }

1;
