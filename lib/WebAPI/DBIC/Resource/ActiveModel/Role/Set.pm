package WebAPI::DBIC::Resource::ActiveModel::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::Set - add content type support for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

=cut

use Moo::Role;

use Carp qw(confess);

use WebAPI::DBIC::Serializer::ActiveModel;

requires '_build_content_types_provided';
requires 'encode_json';
requires 'set';
requires 'serializer';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->to_json_as_activemodel;
        },
    };
    return $types;
};


sub to_json_as_activemodel {
    my $self = shift;
    return $self->encode_json( $self->serializer->render_activemodel_response() );
}


1;
