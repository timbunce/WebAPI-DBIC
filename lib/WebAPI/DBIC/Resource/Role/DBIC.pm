package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

# XXX probably shouldn't be a role, just a function

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item {
    my $item = $_[1];
    my %data = $item->get_inflated_columns;
    # FKs
    # DateTimes
    return \%data;
}

1;
