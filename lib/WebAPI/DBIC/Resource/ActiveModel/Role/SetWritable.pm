package WebAPI::DBIC::Resource::ActiveModel::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::SetWritable - methods handling requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::ActiveModel;

requires 'serializer';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->serializer->set_from_json;
        },
    };
    return $types;
};


1;
