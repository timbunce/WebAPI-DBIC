package WebAPI::DBIC::Serializer::Base;

=head1 NAME

WebAPI::DBIC::Serializer::Base - what will I become?

=cut

use Moo;


has resource => (
    is => 'ro',
    required => 1,
    weak_ref => 1,
    # XXX these are here for now to ease migration to use of a serializer object
    # they also serve to identify areas that probably need refactoring/abstracting
    handles => [qw(
        set

        type_namer
        get_url_template_for_set_relationship
        get_url_for_item_relationship
        uri_for
        prefetch
        param
        add_params_to_url
        path_for_item
        web_machine_resource
    )],
);


# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # XXX inflation, DateTimes, etc.
    return $data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain_hash($_) } $set->all ];
    return $set_data;
}


1;
