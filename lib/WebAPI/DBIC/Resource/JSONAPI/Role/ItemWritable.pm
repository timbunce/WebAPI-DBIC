package WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable - methods handling JSON API requests to update item resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;

use Moo::Role;


requires 'decode_json';
requires 'request';

requires '_pre_update_resource_method';


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

    my $data = $self->decode_json( $self->request->content );
    $self->update_resource($data, is_put_replace => 0);

    return;
}


1;
