package WebAPI::DBIC::Resource::ActiveModel::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::ItemWritable - methods handling JSON API requests to update item resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;

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
            return $self->serializer->item_from_json;
        }
    };
    return $types;
};


1;
