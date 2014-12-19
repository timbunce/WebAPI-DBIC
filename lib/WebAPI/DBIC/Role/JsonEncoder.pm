package WebAPI::DBIC::Role::JsonEncoder;

=head1 NAME

WebAPI::DBIC::Resource::Role::JsonEncoder - provides encode_json and decode_json methods

=cut

use JSON::MaybeXS qw(JSON);

use Moo::Role;


has _json_encoder => (
   is => 'ro',
   builder => '_build_json_encoder',
   handles => {
      encode_json => 'encode',
      decode_json => 'decode',
   },
);

sub _build_json_encoder {
    my $codec = JSON->new->ascii;
    $codec->canonical->pretty if $ENV{WEBAPI_DBIC_DEBUG};
    return $codec;
}

1;
