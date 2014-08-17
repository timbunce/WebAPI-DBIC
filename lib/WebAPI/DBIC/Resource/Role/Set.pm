package WebAPI::DBIC::Resource::Role::Set;

=head1 NAME

WebAPI::DBIC::Resource::Role::Set - methods related to handling requests for set resources

=head1 DESCRIPTION

Handles GET and HEAD requests for requests representing set resources, e.g.
the rows of a database table.

Supports the C<application/hal+json> and C<application/json> content types.

=cut

use Moo::Role;


requires 'encode_json';
requires 'render_set_as_plain';
requires 'render_set_as_hal';


sub allowed_methods { return [ qw(GET HEAD) ] }

sub content_types_provided { return [
    {'application/hal+json' => 'to_hal_json'},
    {'application/json'     => 'to_plain_json'},
] } 

sub to_plain_json { return $_[0]->encode_json($_[0]->render_set_as_plain($_[0]->set)) }
sub to_hal_json   { return $_[0]->encode_json($_[0]->render_set_as_hal(  $_[0]->set)) }

1;
