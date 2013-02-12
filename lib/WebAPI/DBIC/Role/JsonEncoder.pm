package WebAPI::DBIC::Role::JsonEncoder;

use Moo::Role;

use JSON::XS ();

has _json_encoder => (
   is => 'ro',
   lazy => 1,
   builder => '_build_json_encoder',
   handles => {
      encode_json => 'encode',
      decode_json => 'decode',
   },
);

sub _build_json_encoder { JSON::XS->new->ascii }

1;
