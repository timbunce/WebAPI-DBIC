package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain {
    my ($self, $item) = @_;
    my $item_data = { $item->get_inflated_columns }; # XXX ?
    # FKs
    # DateTimes
    return $item_data;
}

sub render_item_as_hal {
    my ($self, $item) = @_;
    my $item_data = $self->render_item_as_plain($item);
    $item_data->{_links} = {
    };
    return $item_data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain($_) } $set->all ];
    return $set_data;
}

1;
