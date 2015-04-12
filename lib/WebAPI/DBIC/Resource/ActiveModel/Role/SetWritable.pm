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


requires '_build_content_types_accepted';
requires 'render_item_into_body';
requires 'decode_json';
requires 'set';
requires 'prefetch';


around '_build_content_types_accepted' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/json' => 'from_activemodel_json' };
    return $types;
};


sub from_activemodel_json {
    my $self = shift;
    my $item = $self->create_resources_from_activemodel( $self->decode_json($self->request->content) );
    return $self->item($item);
}


sub create_resources_from_activemodel { # XXX unify with create_resource in SetWritable, like ItemWritable?
    my ($self, $activemodel) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;

    # There can only be one.
    # If ever Ember supports creating multiple related objects in a single call,
    # (or multiple rows/instances of the same object in a single call)
    # this will have to change.
    croak "The ActiveModel media-type does not support creating multiple rows in a single call (@{[ %$activemodel ]})"
        if(scalar(keys(%{ $activemodel })) > 1);
    my ($result_key, $new_item) = each(%{ $activemodel });

    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources_from_activemodel($new_item, $self->set->result_class);

        # resync with what's (now) in the db to pick up defaulted fields etc
        $item->discard_changes();

        # The other resources do this conditionally based on whether $self->prefetch contains self,
        # but this required significant acrobatics to get working in Ember, and always returning new
        # object data is not harmful, so do this by default.
        # called here because create_path() is too late for Web::Machine
        # and we need it to happen inside the transaction for rollback=1 to work
        $self->render_item_into_body(
            set => $self->set,
            item => $item,
            result_key => $result_key,
            type_namer => $self->type_namer,
            prefetch => undef,
        );

        $schema->txn_rollback if $self->param('rollback'); # XXX

    });

    return $item;
}


sub _create_embedded_resources_from_activemodel {
    my ($self, $activemodel, $result_class) = @_;

    return $self->set->result_source->schema->resultset($result_class)->create($activemodel);
}

1;
