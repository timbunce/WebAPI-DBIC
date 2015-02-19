package WebAPI::DBIC::Serializer::HAL;

use Moo;
use Safe::Isa;

with 'WebAPI::DBIC::Role::JsonEncoder';

has prefetch => (
    is      => 'rw',
    default => sub {{}},
    lazy    => 1
);

#has router   => (
#    is  => 'ro',
#    isa => sub {
#        die unless $_[1]->$_can('get_uri_for')
#    },
#    required => 1
#);

around 'encode_json' => sub {
    my ($orig, $self,) = @_;
    return $self->$orig($self->to_hal(@_));
};

sub to_hal {
    my ($self, $input, $is_embedded) = @_;

    return {} unless $input;
    if ($input->$_isa('DBIx::Class::ResultSet')){
        return $self->set_to_hal($input, $is_embedded);
    } else {
        return $self->item_to_hal($input, $is_embedded);
    }
}

sub set_to_hal {
    my ($self, $set, $is_embedded) = @_;

    my @output = map { $self->item_to_hal($_, $is_embedded) } $set->all;
    return unless @output;

    my $output = scalar @output == 1 ? shift @output : \@output;
    return $is_embedded ? $output : {_embedded => { $self->name_for_source($set) => $output} };
}

sub item_to_hal {
    my ($self, $item, $is_embedded) = @_;

    my $hal_hash = $self->get_column_data($item);

    $hal_hash->{_links} = $self->get_link_data($item) unless $is_embedded;

    # FIXME: accessing the {related_resultsets} key on an Row object is very hacky
    # we should traverse the prefetch param until the Row api improves.
    while (my ($relation_key, $related_result) = each %{$item->{related_resultsets}}){
        next unless $related_result->get_cache; # Data not returned from DB
        my $result = $self->to_hal($related_result, 1);
        $hal_hash->{_embedded}{$relation_key} = $result if $result;
    }

    return $hal_hash;

}

sub name_for_source {
    return $_[1]->result_source->source_name;
}

sub get_link_data {
    my ($self, $item) = @_;
    # FIXME: Get link data from Router.
    return {self => {href => '/'.$item->result_source->source_name.'/1'}}
}

sub get_column_data {
    my ($self, $item) = @_;

    return { $item->get_columns };
}

1;
