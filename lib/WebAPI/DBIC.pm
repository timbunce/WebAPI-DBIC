package WebAPI::DBIC;

=head1 NAME

WebAPI::DBIC - A composable RESTful JSON+HAL API to DBIx::Class schemas using roles, Web::Machine and Path::Router

=head1 STATUS

The WebAPI::DBIC code has been in production use for over a year, however it's
only recently been open sourced (July 2014) so it's still lacking in
documentation, tests etc.

It's also likely to undergo a period of refactoring now there are more
developers contributing and the code is being applied to more domains.
Interested? Please get involved! See L</HOW TO GET HELP> below.

=head1 DESCRIPTION

WebAPI::DBIC provides the parts you need to build a feature-rich RESTful JSON web
service API backed by DBIx::Class schemas.

WebAPI::DBIC features include:

* Use of the JSON+HAL (Hypertext Application Language) lean hypermedia type

* Automatic detection and exposure of result set relationships as HAL C<_links>

* Supports safe robust multi-related-record CRUD transactions

* Built on the strong foundations of L<Web::Machine>, L<Path::Router> and L<Plack>

* Built as fine-grained roles for maximum reusability and extensibility

* A built-in copy of the generic HAL API browser application

* An example command-line utility that gives you an instant web service for any DBIx::Class schema


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


=head2 Web::Machine

The L<Web::Machine> module provides a RESTful web framework modeled as a formal
state machine. This is a rigorous and powerful approach, originally developed in Haskel and since ported to 
See L<https://raw.githubusercontent.com/basho/webmachine/develop/docs/http-headers-status-v3.png>
for an image of the state machine.

By building on Web::Machine, WebAPI::DBIC removes the need to implement all the
logic needed for accurate and full-features HTTP protocol behaviour.
You just provide small pieces of logic at the decision points you care about
and Web::Machine looks after the rest.

See L<https://github.com/basho/webmachine/wiki> for more information.

Web::Machine provides the logic to handle a HTTP request for a I<single resource>.

With WebAPI::DBIC those resources typically represent a DBIx::Class result set,
a row, or a method invocation on a row. They are implemented as a subclass of
L<Web::Machine::Resource> that consumes a some set of WebAPI::DBIC roles that add
the specific desired functionality.


=head2 Path::Router

The L<Path::Router> module is used to organize multiple resources into a URL
namespace. It's used to route incoming requests to the appropriate Web::Machine
instance. It's also used in reverse to construct links to other resources that
are included in the outgoing responses.

Path::Router supports full reversability: the value produced by a path match
can be passed back in and you will get the same path you originally put in.
This removes ambiguity and reduces mis-routings. This is important for
WebAPI::DBIC because, for each resource returned, it automatically add HAL
C<_links> containing the URLs of the related resources, as defined by the
DBIx::Class schema. This is what makes the API discoverable and browseable.


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
    extends 'WebAPI::DBIC::Resource::Base'; # is just Web::Machine::Resource
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


=head1 HOW TO GET HELP

=over

=item * IRC: irc.perl.org#webapi

=for html
<a href="https://chat.mibbit.com/#webapi@irc.perl.org">(click for instant chatroom login)</a>

=for comment
=item * RT Bug Tracker: L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=WebAPI-DBIC>

=item * Source: L<https://github.com/timbunce/WebAPI-DBIC>

=back


=head1 CREDITS

Stevan Little gets top billing for creating L<Web::Machine> and L<Path::Router>
(not to mention L<Moose> and much else besides).

Matt Trout and Peter Rabbitson and the rest of the L<DBIx::Class> team for
creating and maintaining such an excellent object <-> relational mapper.

Arthur Axel "fREW" Schmidt, both for his original "drinkup" prototype using
Web::Machine that WebAPI::DBIC is based on, and for offering to help with the
work required to open source and release WebAPI::DBIC to CPAN. Without that,
and further help from Fitz Elliott, WebAPI::DBIC might still be a closed source
internal project.

=cut
