package WebAPI::DBIC::Resource::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::Role::Set - methods related to handling requests for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/json> content type.

=cut

use Moo::Role;


requires 'encode_json';
requires 'serializer';


has content_types_provided => (
    is => 'ro',
    required => 1,
);

sub to_plain_json { return $_[0]->encode_json($_[0]->serializer->render_set_as_plain($_[0]->set)) }

sub allowed_methods {
    my $self = shift;
    return [ qw(GET HEAD PUT POST) ] if $self->writable;
    return [ qw(GET HEAD) ];
}


# ====== Writable ======

has item => ( # for POST to create
    is => 'rw',
);

has content_types_accepted => (
    is => 'ro',
    required => 1,
);

sub post_is_create { return 1 }

sub create_path_after_handler { return 1 }

sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}


1;
