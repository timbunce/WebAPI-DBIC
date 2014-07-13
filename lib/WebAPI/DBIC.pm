package WebAPI::DBIC;

=head1 NAME

WebAPI::DBIC - A composable RESTful JSON+HAL API to DBIx::Class schemas using roles, Web::Machine and Path::Router

=head1 SYNOPSIS

    TBD - a one-line command to start a web service for a DBIx::Class schema

plus

    TBD - a few lines of code to do the same thing

=head1 DESCRIPTION

WebAPI::DBIC provides the parts you need to build a feature-rich RESTful JSON web
service API backed by DBIx::Class schemas. It also provides a PSGI file that
gives you an instant web service for any DBIx::Class schema with a single command.

WebAPI::DBIC features include:

* Uses the JSON+HAL (Hypertext Application Language) lean hypermedia type

* Supports safe robust multi-related-record CRUD transactions

* Built on the strong foundations of L<Web::Machine> and L<Path::Router>

* Built as fine-grained roles for maximum reusability and extensibility

=head2 HAL - Hypertext Application Language

The Hypertext Application Language hypermedia type (or HAL for short)
is a simple JSON format that gives a consistent and easy way to hyperlink
between resources in your API.

Adopting HAL makes the API explorable, and its documentation easily
discoverable from within the API itself.  In short, it will make your API
easier to work with and therefore more attractive to client developers.

A JavaScript "HAL Browser" is included in the WebAPI::DBIC distribution.
(WebAPI::DBIC doesn't yet offer direct support for documentation resources.)

APIs that adopt HAL can be easily served and consumed using open source
libraries available for most major programming languages. It's also simple
enough that you can just deal with it as you would any other JSON.

See L<http://stateless.co/hal_specification.html> for more details.

=head1 MODULES

=head2 Roles

L<WebAPI::DBIC::Resource::Role::DBIC> is responsible for interfacing with
L<DBIx::Class>, 'rendering' individual records as resource data structures.
It also interfaces with Path::Router to handle relationship linking.

L<WebAPI::DBIC::Resource::Role::SetRender> is responsible for rendering an
entire result set as either plain JSON or JSON+HAL by iterating over the
individual items. For JSON+HAL it adds the paging links.

L<WebAPI::DBIC::Resource::Role::Set> is responsible for accepting GET and HEAD
requests for set resources (collections) and returning the results as JSON or JSON+HAL.

L<WebAPI::DBIC::Resource::Role::SetWritable> is responsible for accepting POST
request for set resources. It handles the recursive creation of related records.
Related records can be nested to any depth and are created from the bottom up
within a transaction.

L<WebAPI::DBIC::Resource::Role::Item> is responsible for GET and HEAD requests
for single item resources and returning the results as JSON or JSON+HAL.

L<WebAPI::DBIC::Resource::Role::ItemWritable> is responsible for accepting PUT
and DELETE requests for single item resources. It handles the recursive update of
related records.  Related records can be nested to any depth and are updated
from the bottom up within a transaction.  Handles both 'PUT is replace' and
'PUT is update' logic.

L<WebAPI::DBIC::Resource::Role::ItemInvoke> is responsible for accepting POST
requests for single item resources representing the invocation of a specific
method on an item (e.g. POST /widget/42/invoke/my_method_name?args=...).

L<WebAPI::DBIC::Resource::Role::DBICAuth> is responsible for checking
authorization to access a resource. It currently supports Basic Authentication,
using the DBI DSN as the realm name and the return username and password as the
username and password for the database connection.

L<WebAPI::DBIC::Resource::Role::DBICParams> is responsible for handling request
parameters related to DBIx::Class such as C<page>, C<rows>, C<order>, C<me>,
C<prefetch>, C<fields> etc.

=head2 Utility Roles

L<WebAPI::DBIC::Role::JsonEncoder> provides encode_json() and decode_json() methods.

L<WebAPI::DBIC::Role::JsonParams> provides a param() method that returns query
parameters, except that any parameters with names that have a C<~json> suffix
have their values JSON decoded, so they can be arbitrary data structures.

=head2 Resource Classes

To make building typical applications easier, WebAPI::DBIC provides three
pre-defined resource classes:

L<WebAPI::DBIC::Resource::GenericItemDBIC> for resources represented by an
individual DBIx::Class row.

L<WebAPI::DBIC::Resource::GenericSetDBIC> for resources represented by a
DBIx::Class result set.

L<WebAPI::DBIC::Resource::GenericItemInvoke> for resources that represent a
specific method call on an item resource.

These classes are I<very> simple because all the work is done by the various
roles they consume. For example, here's the entire code for
L<WebAPI::DBIC::Resource::GenericItemDBIC>:

    package WebAPI::DBIC::Resource::GenericItemDBIC;
    use Moo;
    extends 'Web::Machine::Resource';
    with    'WebAPI::DBIC::Role::JsonEncoder',
            'WebAPI::DBIC::Role::JsonParams',
            'WebAPI::DBIC::Resource::Role::DBIC',
            'WebAPI::DBIC::Resource::Role::DBICAuth',
            'WebAPI::DBIC::Resource::Role::DBICParams',
            'WebAPI::DBIC::Resource::Role::Item',
            'WebAPI::DBIC::Resource::Role::ItemWritable',
            ;
    1;


=head2 Other Classes

A few other classes are provided:

L<WebAPI::DBIC::Util.pm> provides a few general utilities.

L<WebAPI::DBIC::Machine.pm> a subclass of L<Web::Machine>.

L<WebAPI::DBIC::WebApp> - this is the main app class and is most likely to
change in the near future so isn't documented yet.

=cut
