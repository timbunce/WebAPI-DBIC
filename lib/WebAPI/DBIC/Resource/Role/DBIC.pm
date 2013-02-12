package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain {
    my ($self, $item) = @_;
    my $data = { $item->get_inflated_columns }; # XXX ?
    # FKs
    # DateTimes
    return $data;
}

sub render_item_as_hal {
    my ($self, $item) = @_;
    my $data = $self->render_item_as_plain($item);
    $data->{_links} = {
        self => { href => "/person_types/".$item->id }
    };
    return $data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain($_) } $set->all ];
    return $set_data;
}

sub render_set_as_hal {
    my ($self, $set) = @_;
    my $data = {
       _embedded => {
          person_types => [ map { $self->render_item_as_hal($_) } $set->all ],
      }
    };
    $data->{_links} = {
        self => { href => "/person_types" }
    };
    return $data;
}

1;
