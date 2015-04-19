package WebAPI::DBIC::Resource::JSONAPI::Role::Item;

=head1 NAME

WebAPI::DBIC::Resource::JSONAPI::Role::Item - methods related to handling JSON API requests for item resources

=head1 DESCRIPTION

Provides methods to support the C<application/vnd.api+json> media type
for GET and HEAD requests for requests representing individual resources,
e.g. a single row of a database table.

=cut

use Moo::Role;

use WebAPI::DBIC::Serializer::JSONAPI;


requires '_build_content_types_provided';
requires 'encode_json';
requires 'item';
requires 'serializer';

requires 'set';
requires 'id_unique_constraint_name';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/vnd.api+json' => sub {
            my $self = shift;
            $self->serializer(WebAPI::DBIC::Serializer::JSONAPI->new(resource => $self));
            return $self->to_json_as_jsonapi
        },
    };
    return $types;
};


sub to_json_as_jsonapi {
    my $self = shift;

    # narrow the set to just contain the specified item
    # XXX this narrowing ought to be moved elsewhere
    # seems like a bad idea to be a side effect of to_json_as_jsonapi
    my @id_cols = $self->set->result_source->unique_constraint_columns( $self->id_unique_constraint_name );
    @id_cols = map { $self->set->current_source_alias.".$_" } @id_cols;
    my %id_search; @id_search{ @id_cols } = @{ $self->id };
    $self->set( $self->set->search_rs(\%id_search) ); # narrow the set

    # set has been narrowed to the item, so we can render the item as if a set
    # (which is what we need to do for JSON API, which doesn't really have an 'item')

    return $self->encode_json( $self->serializer->render_jsonapi_response() );
}

1;
