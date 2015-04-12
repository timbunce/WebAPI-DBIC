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

sub to_json_as_activemodel {
    my $self = shift;

    # narrow the set to just contain the specified item
    # XXX this narrowing ought to be moved elsewhere
    # it's a bad idea to be a side effect of to_json_as_activemodel
    my @id_cols = $self->set->result_source->unique_constraint_columns( $self->id_unique_constraint_name );
    @id_cols = map { $self->set->current_source_alias.".$_" } @id_cols;
    my %id_search; @id_search{ @id_cols } = @{ $self->id };
    $self->set( $self->set->search_rs(\%id_search) ); # narrow the set

    # set has been narrowed to the item, so we can render the item as if a set
    # (which is what we need to do for JSON API, which doesn't really have an 'item')

    return $self->encode_json( $self->render_activemodel_response() );
}

1;
