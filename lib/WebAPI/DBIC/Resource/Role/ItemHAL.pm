package WebAPI::DBIC::Resource::Role::ItemHAL;

=head1 NAME

WebAPI::DBIC::Resource::Role::ItemHAL - methods related to handling HAL requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/hal+json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

=cut

use Moo::Role;


requires '_build_content_types_provided';
requires 'render_item_as_hal_hash';
requires 'encode_json';
requires 'item';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/hal+json' => 'to_json_as_hal' };
    return $types;
};

sub to_json_as_hal { return $_[0]->encode_json($_[0]->render_item_as_hal_hash($_[0]->item)) }

1;
