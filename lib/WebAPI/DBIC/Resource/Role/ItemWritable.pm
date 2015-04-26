package WebAPI::DBIC::Resource::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::Role::ItemWritable - methods handling requests to update item resources

=cut

use Moo::Role;

requires 'item';


# By default the DBIx::Class::Row update() call will only update the
# columns where %$hal contains different values to the ones in $item.
# This is usually a useful optimization but not always. So we provide
# a way to disable it on individual resources.
has skip_dirty_check => (
    is => 'rw',
);

has _pre_update_resource_method => (
    is => 'rw',
);

has content_types_accepted => (
    is => 'lazy',
);

sub _build_content_types_accepted {
    return [
        {
        'application/vnd.wapid+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::WAPID;
            $self->serializer(WebAPI::DBIC::Serializer::WAPID->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        },
    },
    {
        'application/json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::ActiveModel;
            $self->serializer(WebAPI::DBIC::Serializer::ActiveModel->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        }
    },
    {
        'application/hal+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::HAL;
            $self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        },
    },
    {
        'application/vnd.api+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::JSONAPI;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->serializer->item_from_json($self->request->content);
        },
    },

];
}


around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;
 
    my $methods = $self->$orig();

    $methods = [ qw(PUT DELETE), @$methods ] if $self->writable;

    return $methods;
};


sub delete_resource { return $_[0]->item->delete }


1;
