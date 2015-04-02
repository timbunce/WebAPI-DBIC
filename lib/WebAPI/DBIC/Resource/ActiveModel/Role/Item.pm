package WebAPI::DBIC::Resource::ActiveModel::Role::Item;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::Item - methods related to handling requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

The response is intended to be compatible with the Ember Data ActiveModelAdapter
L<http://emberjs.com/api/data/classes/DS.ActiveModelAdapter.html>

=cut

use Moo::Role;


requires '_build_content_types_provided';
requires 'render_item_as_activemodel_hash';
requires 'encode_json';
requires 'item';


has result_key => (
    is => 'rw',
);


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/json' => 'to_json_as_activemodel' };
    return $types;
};

sub to_json_as_activemodel { return $_[0]->encode_json($_[0]->render_item_as_activemodel_hash($_[0]->item)) }

1;
