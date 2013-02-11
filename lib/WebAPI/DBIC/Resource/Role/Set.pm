package WebAPI::DBIC::Resource::Role::Set;

# Based on https://github.com/frioux/drinkup

use Moo::Role;

requires 'render_item';
requires 'decode_json';
requires 'encode_json';

has set => (
   is => 'ro',
   required => 1,
);

has item => ( # POST
   is => 'rw',
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
   $_[0]->request->request_uri . '/%i'
}

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable ) ? (qw(POST)) : ()
   ]
}

sub post_is_create { 1 }

sub create_path_after_handler { 1 }

sub create_path {
    my $self = shift;
    my $item = $self->item;
   return sprintf $self->post_redirect_template,
      map { $item->get_column($_) } $item->result_source->primary_columns
}

sub content_types_provided { [ {'application/json' => 'to_json'} ] }
sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub to_json { $_[0]->encode_json([ map $_[0]->render_item($_), $_[0]->set->all ]) }

sub from_json {
    my $self = shift;
    $self->item($self->create_resource($self->decode_json($self->request->content)));
}

sub create_resource { $_[0]->set->create($_[1]) }

1;
