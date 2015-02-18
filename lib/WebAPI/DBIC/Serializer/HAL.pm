package WebAPI::DBIC::Serializer::HAL;

use Moo;

with 'WebAPI::DBIC::Role::JsonEncoder';

use Safe::Isa;

around 'encode_json' => sub {
    my ($orig, $self,) = @_;
    return $self->$orig($self->to_hal(@_));
};

sub get_column_data {
    my ($self, $item) = @_;

    return { $item->get_columns };
}

sub get_link_data {
    my ($self, $item) = @_;
    return {};
}

sub to_hal {
    my ($self, $input, $is_embedded) = @_;

    if ($input->$_isa('DBIx::Class::ResultSet')){
        my @output;
        for my $item ($input->next){
            push @output, $self->to_hal($item, 1);
        }

        return scalar @output == 1 ? shift @output : \@output;
    } else {
        my $hal_hash = $self->get_column_data($input);
        $hal_hash->{_links} = $self->get_link_data($input) unless $is_embedded;

        for my $relation_key ($input->result_source->relationships){
            my $related_result = $input->$relation_key;
            next unless $related_result->get_cache; # Data not returned from DB
            $hal_hash->{_embedded}{$relation_key} = $self->to_hal($related_result, 1);
        }

        return $hal_hash;
    }
}

1;
