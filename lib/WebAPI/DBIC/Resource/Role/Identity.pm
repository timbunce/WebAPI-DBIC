package WebAPI::DBIC::Resource::Role::Identity;

use Moo::Role;

use Carp qw(confess);


requires 'item';


has id_unique_constraint_name => (
   is => 'ro',
   default => 'primary',
);


sub id_from_key_values {
    my $self = shift;
    return undef if grep { not defined } @_; # return undef if any key field is undef
    return join "=", @_; # XXX need to think more about multicolumn pks and fks
}


sub key_values_from_id {
    my ($self, $id) = @_;
    my @vals = split /=/, $id; # XXX need to think more about multicolumn pks and fks
    return @vals;
}


sub id_for_item {
    my ($self, $item) = @_;

    # Note that we're using the unique_constraint_name from the instance
    # but we're not using the item of the instance because, eg, the $item
    # may be a new item. This is a little suspect. We possibly ought to create
    # a new instance of the resource and use that. Meanwhile we'll be cautious:
    confess "panic: mixed item result_class"
        if $self->item and $item->result_source->result_class ne $self->item->result_source->result_class;

    my $unique_constraint_name = $self->id_unique_constraint_name;

    my @c_vals = map {
        $item->get_column($_)
    } $item->result_source->unique_constraint_columns($unique_constraint_name);

    return $self->id_from_key_values( @c_vals );
}



1;
