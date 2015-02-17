=head1 NAME

WebAPI::DBIC::Resource::HAL - HAL support for WebAPI::DBIC

=head2 HAL - Hypertext Application Language

The Hypertext Application Language hypermedia type (or HAL for short)
is a simple JSON format that gives a consistent and easy way to hyperlink
between resources in your API. It uses the C<application/hal+json> media type.

Adopting HAL makes the API explorable, and its documentation easily
discoverable from within the API itself.  In short, it will make your API
easier to work with and therefore more attractive to client developers.

A pure-JavaScript "HAL Browser" application is included in the WebAPI::DBIC
distribution via the L<Alien::Web::HalBrowser> module.

APIs that adopt HAL can be easily served and consumed using open source
libraries available for most major programming languages. It's also simple
enough that you can just deal with it as you would any other JSON.

See L<http://stateless.co/hal_specification.html>
for more details of the specification.

=head2 Roles

The L<WebAPI::DBIC::Resource::HAL::Role::DBIC> role provides core methods
to support HAL data structures used by the other HAL roles listed below.

The L<WebAPI::DBIC::Resource::HAL::Role::Set> and
L<WebAPI::DBIC::Resource::HAL::Role::Item> roles handle GET and HEAD requests
for set (resultset) and item (row) resources.

The L<WebAPI::DBIC::Resource::HAL::Role::SetWritable> role handles POST requests
to set (resultset) resources. It handles the recursive creation of related records.
Related records can be nested to any depth and are created from the bottom up
within a transaction.

The L<WebAPI::DBIC::Resource::HAL::Role::ItemWritable> roles handle PUT and DELETE
requests for item (row) resources. It handles the recursive update of
related records.  Related records can be nested to any depth and are updated
from the bottom up within a transaction.  Handles both 'PUT is replace' and
'PUT is update' logic.

The L<WebAPI::DBIC::Resource::HAL::Role::Root> role handles GET and HEAD
requests for the 'root' of an application. It returns a HAL data structure that
describes the available resources and enables navigation of the API by the
pure-javascript interactive API browser L<Alien::Web::HalBrowser>.

=head3 Implementation Limitations

WebAPI::DBIC doesn't yet offer direct support for documentation resources.

=cut
