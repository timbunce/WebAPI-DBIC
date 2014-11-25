# WebAPI::DBIC

A composable RESTful JSON+HAL API to DBIx::Class schemas using roles, Web::Machine and Path::Router

[![Build Status](https://secure.travis-ci.org/timbunce/WebAPI-DBIC.png)](http://travis-ci.org/timbunce/WebAPI-DBIC)
[![Coverage Status](https://coveralls.io/repos/timbunce/WebAPI-DBIC/badge.png)](https://coveralls.io/r/timbunce/WebAPI-DBIC)

# DESCRIPTION

WebAPI::DBIC provides the parts you need to build a feature-rich RESTful JSON web
service API backed by DBIx::Class schemas.

WebAPI::DBIC features include:

* Built on the strong foundations of
[Plack](https://metacpan.org/pod/Plack) and
[Web::Machine](https://metacpan.org/pod/Web::Machine),
plus [Path::Router](https://metacpan.org/pod/Path::Router) as the router
(other routers could be supported).

* Built as fine-grained roles for maximum reusability and extensibility.

* Integrates with other Plack-based applications.

* The resource roles can be added to your existing application.

* Rich support for multiple hypermedia types, including JSON API
(`application/vnd.api+json`) and HAL (`application/hal+json`).
The Collection+JSON hypermedia type could be added in future.

* Automatic detection and exposure of result set relationships.

* Supports safe robust multi-related-record CRUD transactions.

* An example .psgi file that gives you an instant web service for any
DBIx::Class schema.

* Includes a built-in copy of the generic HAL API browser application so you
can be browsing your new API in mimutes.


# HAL - Hypertext Application Language

The [Hypertext Application Language](http://stateless.co/hal_specification.html)
hypermedia type (or HAL for short)
is a simple JSON format that gives a consistent and easy way to hyperlink
between resources in your API.

Adopting HAL makes the API explorable, and its documentation easily
discoverable from within the API itself.  In short, it will make your API
easier to work with and therefore more attractive to client developers.

A JavaScript "HAL Browser" is included in the WebAPI::DBIC distribution.

APIs that adopt HAL can be easily served and consumed using [open source
libraries available for most major programming languages](https://github.com/mikekelly/hal_specification/wiki/Libraries).
It's also simple enough that you can just deal with it as you would any other
JSON.  


# JSON API

The JSON API media type is designed to minimize both the number of requests and
the amount of data transmitted between clients and servers. This efficiency is
achieved without compromising readability, flexibility, and discoverability.

The JSON API support in WebAPI::DBIC is relatively new.
Check the [WebAPI::DBIC documentation](blob/master/lib/WebAPI/DBIC.pm) for the current status.

See [jsonapi.org](http://jsonapi.org/) for more details.

For Ember, [ember-json-api](https://github.com/kurko/ember-json-api) can be used as an adaptor.


# Web::Machine

The Web::Machine module provides a RESTful web framework modeled as a
[formal state machine](https://github.com/basho/webmachine/wiki).
This is a rigorous and powerful approach, originally developed
in Haskel and since ported to many other languages.

By building on Web::Machine, WebAPI::DBIC removes the need to implement all the
logic needed for accurate and full-featured HTTP protocol behaviour.
You just provide small pieces of logic at the decision points you care about
and Web::Machine looks after the rest.

Web::Machine provides the logic to handle a HTTP request for a single resource.

With WebAPI::DBIC those resources typically represent a DBIx::Class result set,
a row, or a method invocation on a row. They are implemented as a subclass of
Web::Machine::Resource that consumes a some set of WebAPI::DBIC roles which add
the desired functionality to the resource.

# QUICK START

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
`WEBAPI_DBIC_WRITABLE` environment variable.

# STATUS

The WebAPI::DBIC code has been in production since mid-2013, however it's only
been open sourced since mid-2014 so it's still lacking in documentation, tests etc.

It's also likely to undergo a period of refactoring now there are more
developers contributing and the code is being applied to more domains.

Interested? Please get involved!

See HOW TO GET HELP in the [WebAPI::DBIC documentation](blob/master/lib/WebAPI/DBIC.pm).


