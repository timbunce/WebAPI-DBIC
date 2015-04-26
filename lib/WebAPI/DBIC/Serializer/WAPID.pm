package WebAPI::DBIC::Serializer::WAPID;

=head1 NAME

WebAPI::DBIC::Serializer::WAPID - Serializer for WebAPI::DBIC's own test media type

=cut

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';

sub content_types_accepted {
    return ( [ 'application/vnd.wapid+json' => 'accept_from_json' ] );
}

sub content_types_provided {
    return ( [ 'application/vnd.wapid+json' => 'provide_to_json' ]);
}



sub _create_embedded_resources_from_data {
    my ($self, $data, $result_class) = @_;

    return $self->set->result_source->schema->resultset($result_class)->create($data);
}

1;
