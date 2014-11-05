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
requires 'render_set_as_plain';


has content_types_provided => (
    is => 'lazy',
);

sub _build_content_types_provided {
    return [ { 'application/json' => 'to_plain_json'} ]
}

sub to_plain_json { return $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }

sub allowed_methods { return [ qw(GET HEAD) ] }

1;
