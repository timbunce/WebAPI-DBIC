=head1 NAME

WebAPI::DBIC::Resource::JSONAPI - JSON API support for WebAPI::DBIC

=head2 Media Type

These roles respond to the C<application/vnd.api+json> media type.

=head2 JSONAPI

The JSON API media type is designed to minimize both the number of requests and
the amount of data transmitted between clients and servers. This efficiency is
achieved without compromising readability, flexibility, and discoverability.

See L<http://jsonapi.org/> for more details.

Development of JSON API support for WebAPI::DBIC has stalled due to instability
of the specification as it moves towards an official 1.0 release.  See, for example,
L<https://github.com/json-api/json-api/issues/159#issuecomment-70675184>

For Ember, L<https://github.com/kurko/ember-json-api> can be used as an adaptor
but has it's own set of issues. I'd recommend using L<WebAPI::DBIC::Resource::ActiveModel> instead.

=head2 Roles

The L<WebAPI::DBIC::Resource::JSONAPI::Role::DBIC> role provides core methods
required to support the other roles listed below.

The L<WebAPI::DBIC::Resource::JSONAPI::Role::Set>
and L<WebAPI::DBIC::Resource::JSONAPI::Role::Item> roles handle GET and HEAD requests
for set (resultset) and item (row) resources.

The L<WebAPI::DBIC::Resource::JSONAPI::Role::SetWritable> role handles POST requests
to set (resultset) resources. It handles the recursive creation of related records.
Related records can be nested to any depth and are created from the bottom up
within a transaction.

The L<WebAPI::DBIC::Resource::JSONAPI::Role::ItemWritable> roles handle PUT and DELETE
requests for item (row) resources. It handles the recursive update of
related records.  Related records can be nested to any depth and are updated
from the bottom up within a transaction.  Handles both 'PUT is replace' and
'PUT is update' logic.

There's no JSONAPI specific handling for invoking methods on resources yet.
You can use the generic L<WebAPI::DBIC::Resource::Role::ItemInvoke> or
L<WebAPI::DBIC::Resource::Role::SetInvoke> role.

=cut
