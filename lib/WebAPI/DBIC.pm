package WebAPI::DBIC;

use strict; # keep our kwalitee up!
use warnings;

=head1 NAME

WebAPI::DBIC - A composable RESTful JSON API to DBIx::Class schemas using roles and Web::Machine

=head1 STATUS

The WebAPI::DBIC code has been in production use since early 2013, however it's
only recently been open sourced (July 2014) so it's still lacking in documentation.
It's also undergoing a period of refactoring, enhancement and evolution now
there are more developers contributing and the code is being applied to more domains.

Interested? Please get involved! See L</HOW TO GET HELP> below.

=head1 DESCRIPTION

WebAPI::DBIC (or "WAPID" for short) provides the parts you need to build a
feature-rich RESTful JSON web service API backed by DBIx::Class schemas.

WebAPI::DBIC features include:

* Built as fine-grained roles for maximum reusability and extensibility.

* Integrates with other L<Plack> based applications.

* The resource roles can be added to your existing application.

* Built on the strong foundations of L<Plack> and L<Web::Machine>, plus
L<Path::Router> as the router. (Other routers could be supported.)

* Rich support for multiple hypermedia types, including ActiveModel / Ember-Data
(C<application/json>), JSON API (C<application/vnd.api+json>)
and HAL (C<application/hal+json>).
The Collection+JSON and JSON-LD hypermedia types could be added in future.

* Automatic detection and exposure of result set relationships.

* Supports safe robust multi-related-record CRUD transactions.

* An example .psgi file that gives you an instant web service for any
DBIx::Class schema.

* A generic pure-javascript HAL API browser application is integrated with
WebAPI::DBIC so you can be browsing your new API in seconds.

=head2 Media Types Supported

The HTTP C<Content-Type> and C<Accept> headers are used to specify
the 'media type' of a request, and the desired response. In the case of JSON
types, the media type defines not only that the content is a JSON data structure,
but the semantics (meaning) of the the scructure.

A single application can support requests and responses in multiple media
types, using the headers to negotiate the right behaviour for ech request.

=head3 ActiveModel

Designed to match the behaviour of the active_model_serializers Ruby gem
and thus be directly usable as a backend for frameworks compatible with it,
including Ember.  This uses the C<application/json> media type. (This is a very
common 'default' media type for web data services.)

See L<WebAPI::DBIC::Resource::ActiveModel> for more information.

=head3 HAL

The Hypertext Application Language hypermedia type (or HAL for short)
is a simple JSON format that gives a consistent and easy way to hyperlink
between resources in your API. It uses the C<application/hal+json> media type.

A pure-JavaScript "HAL Browser" application is integrated with the WebAPI::DBIC
distribution via the L<Alien::Web::HalBrowser> module. It's a great way to
explore your API.

See L<http://stateless.co/hal_specification.html> for more details of the specification.
See L<WebAPI::DBIC::Resource::HAL> for more details of WebAPI::DBIC support.

=head3 JSON API

The JSON API media type is designed to minimize both the number of requests and
the amount of data transmitted between clients and servers. This efficiency is
achieved without compromising readability, flexibility, and discoverability.
It's an (as yet immature) evolution of the ActiveModel media type.

See L<WebAPI::DBIC::Resource::JSONAPI> for more details.

=head3 WAPID

The WebAPI::DBIC core and tests use the C<application/vnd.wapid+json> media
type. It's subject to change without notice.

=head2 Web::Machine

The L<Web::Machine> module provides a RESTful web framework modeled as a formal
state machine. This is a rigorous and powerful approach, originally developed
in Erlang and since ported to many other languages.
See L<https://raw.githubusercontent.com/basho/webmachine/develop/docs/http-headers-status-v3.png>
for an image of the state machine.

By building on Web::Machine, WebAPI::DBIC removes the need to implement all the
logic needed for accurate and full-featured HTTP protocol behaviour.
You just provide small pieces of logic at the decision points you care about
and Web::Machine looks after the rest.
See L<https://github.com/basho/webmachine/wiki> for more information.

Web::Machine provides the logic to handle a HTTP request for a I<single resource>.
With WebAPI::DBIC those resources typically represent a DBIx::Class result set,
a row, or a method invocation on a row or result set. They are implemented as a subclass of
L<Web::Machine::Resource> that consumes a some set of WebAPI::DBIC roles which add
the desired functionality to the resource.


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


=head1 QUICK START

To demonstrate the rich functionality that the combination of DBIx::Class and
HAL provides, the WebAPI::DBIC framework includes a ready-to-use L<Plack> .psgi
file that provides an instant web data service for any DBIx::Class schema.

    $ git clone https://github.com/timbunce/WebAPI-DBIC.git
    $ cd WebAPI-DBIC
    $ cpanm Module::CPANfile
    $ cpanm --installdeps .    # this may take a while

    $ export WEBAPI_DBIC_SCHEMA=DummyLoadedSchema
    $ plackup -Ilib -It/lib webapi-dbic-any.psgi
    ... open a web browser on port 5000 to browse the API

Then try it out with your own schema:

    $ export WEBAPI_DBIC_SCHEMA=Foo::Bar     # your own schema
    $ export WEBAPI_DBIC_HTTP_AUTH_TYPE=none # recommended
    $ export DBI_DSN=dbi:Driver:...          # your own database
    $ export DBI_USER=... # for initial connection, if needed
    $ export DBI_PASS=... # for initial connection, if needed
    $ plackup -Ilib webapi-dbic-any.psgi
    ... open a web browser on port 5000 to browse your new API

The API is read-only by default. To enable PUT, POST, DELETE etc, set the
C<WEBAPI_DBIC_WRITABLE> environment variable.

=head1 MODULES

=head2 Core Roles

L<WebAPI::DBIC::Resource::Role::DBIC> is responsible for interfacing with
L<DBIx::Class>, 'rendering' individual records as resource data structures.
It also interfaces with Path::Router to handle relationship linking.

L<WebAPI::DBIC::Resource::Role::Set> is responsible for accepting GET and HEAD
requests for set resources (collections) and returning the results as JSON.

L<WebAPI::DBIC::Resource::Role::SetWritable> is responsible for accepting POST
request for set resources. It handles the recursive creation of related records.
Related records can be nested to any depth and are created from the bottom up
within a transaction.

L<WebAPI::DBIC::Resource::Role::Item> is responsible for GET and HEAD requests
for single item resources and returning the results as JSON.

L<WebAPI::DBIC::Resource::Role::ItemWritable> is responsible for accepting PUT
and DELETE requests for single item resources. It handles the recursive update of
related records.  Related records can be nested to any depth and are updated
from the bottom up within a transaction.  Handles both 'PUT is replace' and
'PUT is update' logic.

L<WebAPI::DBIC::Resource::Role::ItemInvoke> is responsible for accepting POST
requests for single item resources representing the invocation of a specific
method on an item (e.g. POST /widget/42/invoke/my_method_name?args=...).

L<WebAPI::DBIC::Resource::Role::SetInvoke> is responsible for accepting POST
requests for set resources representing the invocation of a specific
method on a result set (e.g. POST /widget/invoke/my_method_name?args=...).

L<WebAPI::DBIC::Resource::Role::DBICAuth> is responsible for checking
authorization to access a resource. It currently supports Basic Authentication,
using the DBI DSN as the realm name and the return username and password as the
username and password for the database connection.

L<WebAPI::DBIC::Resource::Role::DBICParams> is responsible for handling request
parameters related to DBIx::Class such as C<page>, C<rows>, C<sort>, C<me>,
C<prefetch>, C<fields> etc.


=head2 ActiveModel Roles

For support of the C<application/json> media type, see L<WebAPI::DBIC::Resource::ActiveModel>.

=head2 JSON+HAL Roles

See L<WebAPI::DBIC::Resource::HAL>

=head2 JSON API Roles

See L<WebAPI::DBIC::Resource::JSONAPI>

=head2 Utility Roles

L<WebAPI::DBIC::Role::JsonEncoder> provides encode_json() and decode_json() methods.

L<WebAPI::DBIC::Role::JsonParams> provides a param() method that returns query
parameters, except that any parameters with names that have a C<~json> suffix
have their values JSON decoded, so they can be arbitrary data structures.

=head2 Resource Classes

To make building typical applications easier, WebAPI::DBIC provides several
pre-defined resource classes:

L<WebAPI::DBIC::Resource::GenericCore> is a base class that consumes all the
general-purpose resource roles.

L<WebAPI::DBIC::Resource::GenericSet> subclasses GenericCore and consumes extra
roles for resources represented by a DBIx::Class result set.

L<WebAPI::DBIC::Resource::GenericItem> subclasses GenericCore and consumes
extra roles for resources represented by an individual DBIx::Class row.

L<WebAPI::DBIC::Resource::GenericSetInvoke> subclasses GenericCore and
consumes extra roles for resources that represent a specific method call on a
set resource.

L<WebAPI::DBIC::Resource::GenericItemInvoke> subclasses GenericCore and
consumes extra roles for resources that represent a specific method call on an
item resource.

These classes are I<very> simple because all the work is done by the various
roles they consume. For example, here's the entire code for
L<WebAPI::DBIC::Resource::GenericCore>:

    package WebAPI::DBIC::Resource::GenericCore;
    use Moo;
    extends 'WebAPI::DBIC::Resource::Base';
    with    'WebAPI::DBIC::Role::JsonEncoder',
            'WebAPI::DBIC::Role::JsonParams',
            'WebAPI::DBIC::Resource::Role::Router',
            'WebAPI::DBIC::Resource::Role::Identity',
            'WebAPI::DBIC::Resource::Role::Relationship',
            'WebAPI::DBIC::Resource::Role::DBIC',
            'WebAPI::DBIC::Resource::Role::DBICException',
            'WebAPI::DBIC::Resource::Role::DBICAuth',
            'WebAPI::DBIC::Resource::Role::DBICParams',
            ;
    1;

and L<WebAPI::DBIC::Resource::GenericItem>:

    package WebAPI::DBIC::Resource::GenericSet;
    use Moo;
    extends 'WebAPI::DBIC::Resource::GenericCore';
    with    'WebAPI::DBIC::Resource::Role::Set',
            'WebAPI::DBIC::Resource::Role::SetWritable',
            ;
    1;

=head2 Other Classes

A few other classes are provided:

L<WebAPI::DBIC::Util.pm> provides a few general utilities.

L<WebAPI::DBIC::WebApp> - this is the main app class and is most likely to
change in the near future so isn't documented much yet.


=head1 TRANSPARENCY

WebAPI::DBIC aims to be a fairly 'transparent' layer between your
L<DBIx::Class> schema and the JSON that's generated and received.

So it's the responibility of your schema to return data in the format you want
in your generated URLs and JSON, and to accept data in the format that arrives
in requests from clients.

For an example of how to handle dates using L<DateTime> nicely, see:

  https://blog.afoolishmanifesto.com/posts/solution-on-how-to-serialize-dates-nicely/


=head1 COMPARISONS

This section provides links to similar modules with a few notes about how they
differ from WebAPI::DBIC.

=head2 ... others? ...

=head2 App::AutoCRUD

L<App::AutoCRUD> provides an automatically generated I<HTML> interface to a
database, including search forms. It can export data in various formats
including JSON but isn't designed as a JSON API, so it's not directly
comparable to WebAPI::DBIC. See also L<RapidApp>.

App::AutoCRUD doesn't use DBIx::Class, it uses DBIx::DataModel (a UML-based ORM
framework), but creates the model on the fly. That doesn't let you build
business logic into the schema model the way you can with DBIx::Class.

=head2 RapidApp

To quote the documentation: L<RapidApp> is an extension to L<Catalyst> - the
Perl MVC framework. It provides a feature-rich extended development stack, as
well as easy access to common out-of-the-box application paradigms, such as
powerful CRUD-based front-ends for DBIx::Class models, user access and
authorization, RESTful URL navigation schemes, pure Ajax interfaces with no
browser page loads, templating engine with front-side CMS features, declarative
configuration layers, and more.

It's not designed as a JSON API and doesn't use HAL, so it's not directly
comparable to WebAPI::DBIC.

=head1 INTEGRATIONS

This section provides information on how to integrate WebAPI::DBIC with
existing applications.

=head2 Catalyst

As with any PSGI application, WebAPI::DBIC can integrate into Catalyst fairly
simply with L<Catalyst::Action::FromPSGI>.  Here's an example integration:

 package MyApp::Controller::HelloName;

 use base 'Catalyst::Controller';

 sub api : Path('/api') ActionClass('FromPSGI') {
   my ($self, $c) = @_;

   WebAPI::DBIC::WebApp->new({
     schema   => $c->model('DB')->schema,
     ...
   })->to_psgi_app
 }

=head2 Dancer

I<I'd welcome any information you could contribute here.>

=head2 Mojolicious

I<I'd welcome any information you could contribute here.>

=head2 ...

=head1 HOW TO GET HELP

=over

=item * IRC: irc.perl.org#webapi

=for html
<a href="https://chat.mibbit.com/#webapi@irc.perl.org">(click for instant chatroom login)</a>

=for comment
=item * RT Bug Tracker: L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=WebAPI-DBIC>

=item * Source: L<https://github.com/timbunce/WebAPI-DBIC>

=back

See also https://metacpan.org/pod/distribution/WebAPI-DBIC/NOTES.pod
and https://github.com/timbunce/WebAPI-DBIC/issues

If there's anything you specifically need, just ask!

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


=head1 OVERVIEW OF REPRESENTIONS AND ACTIONS

The docs below are from old internal documentation. They're a bit rought and
will be reworked and found a better home. They're here for now because they are
useful to give a sense of how the API works and what it supports.

=head2 GENERIC ENTITY REPRESENTIONS

Here we define the default behavior for GET, PUT, DELETE and POST methods on
item and set resources.

In these examples the ~ symbol is used to represent a common prefix.  The
prefix is intended to contain at least a single path name element plus a
version number element, for example, in:

    GET ~/ecosystems/

the ~ represents a prefix such as "/clients/v1", so the above is a shorthand
way of representing:

    GET /clients/v1/ecosystems/

=head3 Conventions

Resource names are typically plural nouns, and lower case, with underscores if required.
Verbs could be used for for non-resource requests and might be capitalized (e.g. /Convert?from=Y&to=Y).

A parameter that's part of the url is represented in these examples with the
:name convention, e.g. :id.

XXX That might change to the 'URL Template' RFC6570 style
http://tools.ietf.org/html/rfc6570


=head2 GET Item

    GET ~/resources/:id

returns

    {
        _links: { ... }  # optional
        _embedded: { ... }  # optional
        _meta: { ... }   # optional
        ... # data attributes, optional
    }

The optional _links object holds relevant links in the HAL format
(see below). This enables interactive browsing of the API.

The optional _embedded object holds embedded resources in the HAL format.
(see L</prefetch>).

The optional _meta attribute might include things like the name of the
attribute to treat as the label, or a count of items matching a search.

    GET ~/ecosystems/1

would include

    {
        id: 1,
        ...
        person_id: 2,  # foreign key
        ...
        _links {
            self: {
                href: "/ecosystems/1"
            },
            "relation:person": {
                href: /person/19
            },
            "relation:email_domain": {
                href: "/email_domain/8"
            }
        },
    }

The "relation" links describe the relationships this resource has with other resources.

Also see L</prefetch>.


=head2 GET Item - Optional Parameters

=head3 prefetch

Prefetch is a mechanism in DBIx::Class by which related resultsets can be returned
along with the primary resultset. This prefetching is performed by a single query and
so improves efficiency by reducing the number of database requests.

In WebAPI::DBIC the C<prefetch> parameter enables use of DBIx::Class prefetch and
so allows any data in related resultsets to be returned as part of the same
response. This allows the user to make one GET to return most, and possibly all,
of the data needed by the requesting application. This reduces the number of HTTP requests.

Note that prefetch is only effective for response types that support embedded
data, e.g, C<application/hal+json>.

Prefetching in WebAPI::DBIC and DBIx::Class uses the accessor names defined in the
Result class for the given Resultset. These should be used in the prefetch parameter.

The following examples assume a Schema setup similar to the following:

    package MyApp::Schema::Result::Artist;
    __PACKAGE__->has_many('albums'     => 'MyApp::Schema::Result::CD', 'album_artist');
    __PACKAGE__->has_many('cd_artists' => 'MyApp::Schama::Result::CDArtist', 'artistid');
    __PACKAGE__->belongs_to('producer' => 'MyApp::Schema::Result::Producer', 'producerid');
    __PACKAGE__->many_to_many('cds' => 'cd_artists', 'cd');

    package MyApp::Schema::Result::CD;
    __PACKAGE__->has_many('cd_artists'     => 'MyApp::Schema::Result::CDArtist', 'cdid');
    __PACKAGE__->belongs_to('album_artist' => 'MyApp::Schema::Result::Artist', 'album_artist');
    __PACKAGE__->many_to_many('artists' => 'cd_artists', 'artist');

    package MyApp::Schema::Result::CDArtists;
    __PACKAGE__->belongs_to('cd' => 'MyApp::Schema::Result::CD', 'cdid');
    __PACKAGE__->belongs_to('artist' => 'MyApp::Schema::Result::Artist', 'artistid');


=head4 comma seperated lists

Where all related data for individual directly related resultsets are desired
then a comma seperated list can be provided to the the prefetch parameter

    artist/1?prefetch=producer,albums

(Note that you can't provide the prefetch parameter multiple times to achieve
the same result.)

This would return the following JSON+HAL:

    {
        artistid: 1,
        producerid: 1,
        _embedded: {
            producer: {
                producer: id,
            },
            albums: [{
                cdid: 1,
                album_artist: 1,
            },{
                cdid: 2,
                album_artist: 1,
            }],
        },
        _links: {
            producer: /producer/1,
            albums: /artists/1?albums~json={-or: [{cdid: 1}, {cdid: 2}]} # XXX not correct
        }
    }

=head4 json

The C<prefetch> parameter can be specified as a more complex JSON-encoded
parameter value. This allows for the full use of prefetch chains.
Using key value pairs and lists, prefetches can be nested from one resultset to
another:

    artist/1?prefetch~json={["producer","albums"]}

This would produce the same results as above:

    artist/1?prefetch~json={["producer","cd_artists",{"cds":"album_artist"}]}

would producer the following JSON+HAL:

    {
        artistid: 1,
        producerid: 1,
        _embedded: {
            producer: {
                producer: id,
            },
            cd_artists: [{
                artistsid: 1,
                cdid: 1,
                _embedded: {
                    cd: {
                        cdid: 1,
                        album_artist: 1,
                        _embedded: {
                            album_artist: {
                                artistid: 1,
                                producerid: 1,
                            },
                        },
                        _links: {
                            /album_artist: /artist/1
                        },
                    },
                },
                _links: {
                    cd: /cd/1
                },
            }],
        },
        _links: {
            producer: /producer/1,
            cd_artists: /cdartists?artistid=1&cdid=1,
        }
    }

NOTE: many_to_many relationships can't be supported as they are not true relationships
the related data should be prefetched using the has_many relationship and their join
table as in the above example.

=head4 where on prefetch

The WHERE clause generated can filter results based on related data, as you
would expect in a SQL style JOIN. To refer to fields in related resultsets,
prefix the name of the field with the name of the relationship:

    /artist?prefetch=albumns&albums.title='My CD Title'

This would return all artists which have an album with the title 'My CD Title'.

=head3 fields

The fields parameter can be used to limit the fields returned in the response.
For example:

    fields=field1,field2

This also works
in combination with the prefetch parameter. As with querying on prefetched relations, the
relation accessor should be appended before the field name in question.

    /artist/1?prefetch=albums&fields=artistid,albumns.title

For more information on PREFETCHING and JOINS see L<DBIx::Class::Resultset#PREFETCHING>

NOTE: DBIx::Class does not support the returning of related data if the relationship
accessor for that data matches a column on the requested Set or Item but the fields
parameter does not include that column. You must explicitly request fields if prefetching
a relation with the same name

Using the above example. If the artist has a producer column/field then the following is
invalid:

    /artist/1?prefetch=producer&fields=artistid,producer.producer.producerid

but the following is valid:

    /artist/1?prefetch=producer&fields=artistid,producer,producer.producer.producerid

=head3 with

The C<with> parameter is used to control optional items within responses. It's
a comma separated list of words. This parameter is only passed-through in paging links.

* B<count>

Adds a C<count> attribute to the C<_meta> hash in the results containing the
count of items in the set matched by the request, i.e., the number of items
that would be returned if paging was disabled. Also adds a C<last> link to the
C<_links> section of the results.

* B<nolinks>

TBD - possibly used to disable links in the results, especially for large sets
of small items where the links section would take significant time and space to
construct and return. Might be better as a linkdepth=N where N is decremented
at each level of embedding so linkdepth=0 disables all links, but linkdepth=1
allows paging of the set but doesn't include links in the embedded resources.

=head2 GET on Set

    GET ~/ecosystems

returns

    {
        _links: { ... },  # optional
        _meta: { ... },   # optional
        _embedded: {
            ecosystems => [
                { ... }, ...
            ]
        }
    }

The _embedded object contains a key matching the resource name whoose
value is an array of those resources, in HAL format. It may seem unusual that
the response isn't simply an array of the resources, but you can think of the
'set' as a 'virtual' entity that I<contains nothing itself> but just acts as a
container, or view, for a set of I<embedded resources>.

The _links objects would include links in HAL format for first/prev/next/last.

The _meta could include attributes like limit, offset.

=head2 GET on Set - Optional Parameters

=head3 Paging

Set results are returned in pages to prevent accidentally trying to
fetch very large numbers of rows. The default is a small number.

    rows=N   - default 30 (at the time of writing)
    page=N   - default 1


=head3 fields

Partial results, as for GET Item above.


=head3 Sorting and Ordering

    sort=field1
    sort=field1,-field2

A comma-separated list of one or more ordering clauses. Each clause consists of a
field designator with an optional C<-> prefix to indicate descending order
instead of ascending.

Field names can refer to fields of L</prefetch> relations. For example:

    ~/ecosystems_people?prefetch=person,client_auth&sort=client_auth.username

The parameter name C<order> can be used as a deprecated alias for C<sort>.
The direction can also be specified by appending either "C< asc>" or "C< desc>"
to the field designator. This syntax is deprecated.

=head3 Filtering

    ?me.fieldname=value

Filtering with query params

    ?me.color=red&me.state=running

The me.*= values can be JSON data structures if the field name is sufixed with
~json, for example:

    ?me.color~json=["red","blue"]    # would actually be URL encoded

which would be evaluated as an SQL 'IN' expression:

    color IN ('red', 'blue')

More complex expressions can be expressed using hashes, for example:

    ?me.color~json={"like":"%red%"}  # would actually be URL encoded

would be evaluated as

    color LIKE '%red%'

and

    ?me.foo~json=[ "-and", {"!=":2}, {"!=":1} ]  # shown unencoded

would be evaluated as

    foo != 2 and foo != 1

See https://metacpan.org/module/SQL::Abstract#WHERE-CLAUSES for more examples.

The me.* parameters are only passed-through in paging links.


=head3 Prefetching Related Objects

    ?prefetch=person,client_auth

The resource may have 1-1 and 1-N relationships with other resources.
(E.g., "belongs_to" and "has_many" relationships in DBIx::Class terminology.)

The relevant instances of related resources can be fetched and returned along
with the requested resource by listing the relationships in a prefetch parameter.

For example: GET /ecosystems_people?prefetch=person,client_auth

  {
    "_links": { ... },
    "_embedded": {
      "ecosystems_people": [
        {
          "client_auth_id": "29",
          "person_id": "8",
          ...
          "_links": { ... },
          "_embedded": {
            "client_auth": {   # embedded client_auth resourse
              "id": 29
              ...
            },
            "person": {        # embedded person resourse
              "id": 8,
              ...
            }
          },
        },
        ... # next ecosystems_people resource
      ]
    }
  }


=head3 distinct

    distinct=1

Only return distinct results.

Currently this parameter requires that both the fields and sort parameters are
provided, and have identical values.

The results are returned in HAL format, i.e., as an array of objects in an
_embedded field, but the objects themselves are not in HAL format, i.e. they
don't have _links or _embedded elements.


=head2 PUT on Item

Update resource attributes using the JSON attribute values in the request body.

Embedded related resources can be supplied (if the Content-Type is C<application/hal+json>).

Changes will be made in a single transaction.

Prefetch of related resources is supported.

TODO Enable use of the ETag header for optimistic locking?

=head2 PUT on Set

Not supported.

=head2 DELETE on Item

Delete the record.

=head2 DELETE on Set

Not supported.

=head2 POST on Item

Not supported.

=head2 POST on Set

Create a new resource in the set. Returns a 302 redirect with a Location
header giving the URL of the newly created resource.

Any attributes that aren't specified in the POST data will be given the default
values specified by the database schema.

The C<prefetch> parameter can be used to request that the created resource
(C<prefetch=self>) and any related resources, be returned in the body of the
response.

The rollback=1 parameter let's you rollback a POST to a set, e.g., for testing.

TBD check that only fields valid for GET have been supplied

=head2 Creating Related Resources

If the Content-Type is C<application/hal+json> then related resources can be
provided via the C<_embedded> attribute. They will be created first and the
corresponding key fields of the main resource will be set to the appropriate
values before it's inserted. All database changes will happen in a single transaction.

For example, given a POST to /albums containing:

    {
        name: "album name",
        artist_id: null,        # optional
        _embedded => {
            artist => {
                name: "artist name",
            }
        }
    }

The artist resource would be created first and its primary key would be
used to set the artist_id field before that was created.

This process works recursively for any number of level and any number of
relations at each level.

=head2 Errors

Error status responses should include a JSON object with at least these fields:

    {
        status: NNN,
        message: "...",
    }

XXX Needs to be extended to be able to express errors related to specific
attributes in the request.

The above is out of date. XXX review work on JSON media types for error
reporting (I recall there's one that has adopted HAL).

=head2 Invoking Methods

To enable the execution of functionality not covered by the general HTTP
mechanisms described above, it's possible to define resources that represent
arbitary methods. These methods are executed by a POST request to the
correponding resource. The body of the request contains the parameters to the
method.

Currently a method can only be invoked on an item resource. The resource for
the method call is simply the url of the item resource with '/invoke/:method'
appended:

    POST ~/ecosystems/:id/invoke/:method

The request supports the same query parameters as the corresponding item
resource.

=head3 Default Argument and Response Handling

Custom method resources can be defined which can perform any desired action,
argument and response handling.

A default behaviour is provided to handle simple cases, and that is what is
described here.

The named method is invoked on the item object specified by the item resource.
In other words, the method is a method in the schema's Result class.

The POST request must use content-type of application/json and, if arguments
are required, are specified via an 'args' element in the body JSON:

    { args => [ ... ] }

The method is called in a scalar context.

If the method returns a DBIx::Class::Row object it is returned as a JSON hash.

If the method returns a DBIx::Class ResultSet object it is returned as a JSON
array containing a hash for every row in the result set. There is no paging.

If the method returns any other kind of value it it returned as a JSON hash
containing a single element 'result':

    { result: ... }

(To avoid attempting to serialize objects, if the result is blessed then it's
stringified.)

Note that this default behaviour is liable to change. If you want to make
method calls like this you should define your own resource based on the one provided.

=cut

1;
