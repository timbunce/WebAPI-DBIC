package WebAPI::DBIC::Resource::Role::ItemJSONAPI;

=head1 NAME

WebAPI::DBIC::Resource::Role::ItemJSONAPI - methods related to handling JSONAPI requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/vnd.api+json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

=cut

use Moo::Role;


requires '_build_content_types_provided';
requires 'render_item_as_jsonapi_hash';
requires 'encode_json';
requires 'item';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/vnd.api+json' => 'to_json_as_jsonapi' };
    return $types;
};

#sub to_json_as_jsonapi { return $_[0]->encode_json($_[0]->render_item_as_jsonapi_hash($_[0]->item)) }
sub to_json_as_jsonapi {
    my $self = shift;

    # narrow the set to just contain the spectified item
    my @id_cols = $self->set->result_source->unique_constraint_columns( $self->id_unique_constraint_name );
    my %id_search; @id_search{ @id_cols } = @{ $self->id };
    $self->set( $self->set->search_rs(\%id_search) );

    # XXX back-compat, not sure if needed
    $self->item( $self->set->first ); $self->set->reset;

    return $self->encode_json( $self->render_jsonapi_response( $self->set ) );
}

1;
