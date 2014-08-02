package WebAPI::DBIC::Resource::Role::Identity;

use Moo::Role;


requires 'item';


sub id_for_key_values {
    my $self = shift;
    return undef if grep { not defined } @_; # return undef if any key field is undef
    return join "-", @_; # XXX need to think more about multicolumn pks and fks
}


sub id_for_item {
    my ($self, $item) = @_;

    # assumes that we're using the primary_columns as the identity
    # we should allow alternate keys (eg record vs resource distinction)
    return $self->id_for_key_values(
        map { $item->get_column($_) } $item->result_source->primary_columns
    );
}


1;
