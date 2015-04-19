package WebAPI::DBIC::Resource::ActiveModel::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::SetWritable - methods handling requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

=cut

use Devel::Dwarn;
use Carp qw(croak);

use Moo::Role;

use WebAPI::DBIC::Serializer::ActiveModel;

requires '_build_content_types_accepted';
requires 'decode_json';
requires 'set';
requires 'prefetch';
requires 'serializer';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->from_activemodel_json;
        },
    };
    return $types;
};


sub from_activemodel_json {
    my $self = shift;
    my $item = $self->serializer->create_resources_from_activemodel( $self->decode_json($self->request->content) );
    return $self->item($item);
}


1;
