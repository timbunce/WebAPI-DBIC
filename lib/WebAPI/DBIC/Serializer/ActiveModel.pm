package WebAPI::DBIC::Serializer::ActiveModel;

=head1 NAME

WebAPI::DBIC::Serializer::ActiveModel

=cut

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';


sub activemodel_type {
    my ($self) = @_;
    return $self->type_namer->type_name_for_resultset($self->set);
}

sub activemodel_type_for_class {
    my ($self, $class) = @_;
    return $self->type_namer->type_name_for_result_class($class);
}


sub item_to_json {
    my $self = shift;

    # narrow the set to just contain the specified item
    # XXX this narrowing ought to be moved elsewhere
    # it's a bad idea to be a side effect of to_json_as_activemodel
    my @id_cols = $self->set->result_source->unique_constraint_columns( $self->resource->id_unique_constraint_name );
    @id_cols = map { $self->set->current_source_alias.".$_" } @id_cols;
    my %id_search; @id_search{ @id_cols } = @{ $self->resource->id };
    $self->set( $self->set->search_rs(\%id_search) ); # narrow the set

    # set has been narrowed to the item, so we can render the item as if a set
    # (which is what we need to do for JSON API, which doesn't really have an 'item')

    return $self->resource->encode_json( $self->render_activemodel_response() );
}




sub render_activemodel_prefetch_rel {
    my ($self, $set, $parent_relname, $relname, $rel_sets, $item_edit_rel_hooks) = @_;

    my $parent_class = $set->result_class;
    my $child_class = $parent_class->relationship_info($relname)->{class} || die "panic";

    my @idcolumns = $child_class->unique_constraint_columns('primary'); # XXX wrong
    if (@idcolumns > 1) { # eg many-to-many that doesn't have a separate id
        warn "Child result class $child_class has multiple keys (@idcolumns) so relations like $relname won't have links generated.\n"
            unless our $warn_once->{"$child_class $relname"}++;
        return;
    }

    my $rel_typename = $self->activemodel_type_for_class($child_class);

    return if $item_edit_rel_hooks->{$parent_relname}->{$relname};

    $item_edit_rel_hooks->{$parent_relname}->{$relname} = sub {
        my ($activemodel_obj, $row) = @_;

        my $subitem = $row->$relname();

        my $rel_set = $rel_sets->{$rel_typename} ||= {};

        my $rel_ids;
        if (not defined $subitem) {
            $rel_ids = undef;
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            $rel_ids = [];
            while (my $subrow = $subitem->next) {
                my $id = $subrow->id;
                push @$rel_ids, $id;
                my $rel_object = $self->render_row_as_activemodel_resource_object($subrow, undef, sub {
                    my ($activemodel_obj, $row) = @_;
                    $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{$relname}};
                });
                # In case this object has been pulled in before, do what we can
                # to preserve the existing keys and add to them as appropriate.
                $rel_set->{$id} //= {};
                $rel_set->{$id} = { %{$rel_object}, %{$rel_set->{$id}} };
            }
        }
        elsif ($subitem->isa('DBIx::Class::Row')) { # one-to-one rel
            $rel_ids = $subitem->id;
            my $rel_object = $self->render_row_as_activemodel_resource_object($subitem, undef, sub {
                my ($activemodel_obj, $row) = @_;
                $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{$relname}};
            });
                # In case this object has been pulled in before, do what we can
                # to preserve the existing keys and add to them as appropriate.
            $rel_set->{$subitem->id} //= {};
            $rel_set->{$subitem->id} = { %{$rel_object}, %{$rel_set->{$subitem->id}} };
        }
        else {
            die "panic: don't know how to handle $row $relname value $subitem";
        }

        # XXX We could either create a 'relationship_namer' similar to the 'type_namer',
        # or create a mechanism to facilitate adapter/serializer classes.
        # Per http://emberjs.com/api/data/classes/DS.ActiveModelAdapter.html:
        # This should use the relationship name, singularized, and suffixed with
        # '_id' for belongsTo relationships or '_ids' for hasMany relationships.
        if ($rel_ids) {
            my $suffix = ref($rel_ids) ? '_ids' : '_id';
            my $relname_id = Lingua::EN::Inflect::Number::to_S($relname).$suffix;
            $activemodel_obj->{$relname_id} = $rel_ids;
        }
    }
}


sub render_activemodel_response { # return top-level document hashref
    my ($self) = @_;

    my $set = $self->set;
    my $prefetch = $self->prefetch;

    my $rel_sets = {};
    my $item_edit_rel_hooks = {};

    $self->traverse_prefetch($set, [ 'top' ], $prefetch, sub {
        my ($self, $set, $parent_rel, $prefetch) = @_;
        #warn "$self: $set, $parent_rel, $prefetch\n";
        $self->render_activemodel_prefetch_rel($set, $parent_rel->[-1], $prefetch, $rel_sets, $item_edit_rel_hooks)
    });

    my $result_class = $set->result_class;
    my $set_data = $self->render_set_as_array_of_activemodel_resource_objects($set, undef, sub {
        my ($activemodel_obj, $row) = @_;
        $_->($activemodel_obj, $row) for values %{$item_edit_rel_hooks->{'top'}};
    });

    # construct top document to return
    my $top_set_key = ($self->param('distinct')) ? 'data' : $self->activemodel_type;
    my $top_doc = { # http://jsonapi.org/format/#document-structure-top-level
        $top_set_key => $set_data,
    };

    if (keys %$rel_sets) {
        while ( my ($k, $v) = each %$rel_sets) {
            # sort just for test stability,
            $top_doc->{$k} = [ @{$v}{ sort keys %$v } ];
        }
    }

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $top_doc->{meta}{count} = $total_items; # XXX detail not in spec
    }

    return $top_doc;
}



sub render_item_as_activemodel_hash {
    my ($self, $item) = @_;

    my $data = {
        $self->activemodel_type_for_class($item->result_class)
            => $self->render_item_as_plain_hash($item),
    };

    return $data;
}


sub render_set_as_array_of_activemodel_resource_objects {
    my ($self, $set, $render_method, $edit_hook) = @_;

    my @activemodel_objs;
    while (my $row = $set->next) {
        push @activemodel_objs, $self->render_row_as_activemodel_resource_object($row, $render_method, $edit_hook);
    }

    return \@activemodel_objs;
}

sub render_row_as_activemodel_resource_object {
    my ($self, $row, $render_method, $edit_hook) = @_;
    $render_method ||= 'render_item_as_plain_hash';

    my $obj = $self->$render_method($row);
    $edit_hook->($obj, $row) if $edit_hook;

    return $obj;
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
        $self->resource->render_item_into_body(
            set => $self->set,
            item => $item,
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
