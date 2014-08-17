package WebAPI::DBIC::Resource::Role::Identity;

=head1 NAME

WebAPI::DBIC::Resource::Role::Identity - methods related to the identity of resources

=cut

use Moo::Role;

use Carp qw(carp confess);


requires 'set';
requires 'item';


sub id_unique_constraint_name { # called as static method
   return 'primary',
}


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

    carp "id_for_item called (change to id_kvs_for_item)";

    my $unique_constraint_name = $self->id_unique_constraint_name;

    my @c_vals = map {
        $item->get_column($_)
    } $item->result_source->unique_constraint_columns($unique_constraint_name);

    return $self->id_from_key_values( @c_vals );
}



1;
