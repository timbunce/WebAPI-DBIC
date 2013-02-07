package WebAPI::DBIC::Resource::Role::Set;

use Moo::Role;

requires 'render_item';
requires 'decode_json';
requires 'encode_json';

has set => (
   is => 'ro',
   required => 1,
);

has writable => (
   is => 'ro',
);

has post_redirect_template => (
   is => 'ro',
   lazy => 1,
   builder => '_build_post_redirect_template',
);

sub _build_post_redirect_template {
   $_[0]->request->request_uri . 'data/%i'
}

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable ) ? (qw(POST)) : ()
   ]
}

sub post_is_create { 1 }

sub create_path { "worthless" }

sub content_types_provided { [ {'application/json' => 'to_json'} ] }
sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub to_json { $_[0]->encode_json([ map $_[0]->render_item($_), $_[0]->set->all ]) }

sub from_json {
   my $obj = $_[0]->create_resource(
      $_[0]->decode_json(
         $_[0]->request->content
      )
   );

   $_[0]->redirect_to_new_resource($obj);
}

sub redirect_to_new_resource {
   $_[0]->response->header(
      Location => $_[0]->_post_redirect($_[1])
   );
}

sub _post_redirect {
   sprintf $_[0]->post_redirect_template,
      map $_[1]->get_column($_),
         $_[1]->result_source->primary_columns
}

sub create_resource { $_[0]->set->create($_[1]) }

1;
