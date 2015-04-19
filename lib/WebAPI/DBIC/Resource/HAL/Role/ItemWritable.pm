package WebAPI::DBIC::Resource::HAL::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::ItemWritable - methods handling HAL requests to update item resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;

use Moo::Role;


requires 'decode_json';
requires 'request';
requires 'update_resource';

requires '_pre_update_resource_method';


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

    my $data = $self->decode_json( $self->request->content );
    $self->update_resource($data, is_put_replace => 0);

    return;
}

1;
