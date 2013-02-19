package WebAPI::DBIC::Resource::Role::Set;

# Based on https://github.com/frioux/drinkup

use Moo::Role;

requires 'render_set_as_plain';
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

sub allowed_methods {
   [
      qw(GET HEAD),
      ( $_[0]->writable ) ? (qw(POST)) : ()
   ]
}

sub post_is_create { 1 }

sub create_path_after_handler { 1 }

sub content_types_provided { [
    {'application/hal+json' => 'to_json_as_hal'},
    {'application/json' => 'to_json_as_plain'},
] } 
sub content_types_accepted { [ {'application/json' => 'from_json'} ] }

sub to_json_as_plain { $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }
sub to_json_as_hal   { $_[0]->encode_json($_[0]->render_set_as_hal($_[0]->set)) }

sub from_json {
    my $self = shift;
    $self->item($self->create_resource($self->decode_json($self->request->content)));
}

sub create_resource { $_[0]->set->create($_[1]) }

sub create_path {
    my $self = shift;
    my $item = $self->item;

    my @pricols = $item->result_source->primary_columns;
    die "$self has multiple PK columns" if @pricols != 1;

    # XXX we rely on _n11_create_path to prepend the $self->base_uri
    return $item->get_column(shift @pricols);
}

1;
