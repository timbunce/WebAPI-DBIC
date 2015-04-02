package WebAPI::DBIC::Resource::ActiveModel::Role::DBIC;

=head1 NAME

WebAPI::DBIC::Resource::ActiveModel::Role::DBIC - a role with core methods for DBIx::Class resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'get_url_for_item_relationship';
requires 'render_item_as_plain_hash';
requires 'path_for_item';
requires 'add_params_to_url';
requires 'prefetch';
requires 'type_namer';
requires 'result_key';



sub activemodel_type {
    my ($self) = @_;
    return $self->type_namer->type_name_for_resultset($self->set);
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

    my $rel_typename = $self->type_namer->type_name_for_result_class($child_class);

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
        $self->result_key => $self->render_item_as_plain_hash($item),
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





1;
