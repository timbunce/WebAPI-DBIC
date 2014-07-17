# WebAPI::DBIC

A composable RESTful JSON+HAL API to DBIx::Class schemas using roles, Web::Machine and Path::Router

[![Build Status](https://secure.travis-ci.org/timbunce/WebAPI-DBIC.png)](http://travis-ci.org/timbunce/WebAPI-DBIC)
[![Coverage Status](https://coveralls.io/repos/timbunce/WebAPI-DBIC/badge.png)](https://coveralls.io/r/timbunce/WebAPI-DBIC)

# DESCRIPTION

WebAPI::DBIC provides the parts you need to build a feature-rich RESTful JSON web
service API backed by DBIx::Class schemas.

WebAPI::DBIC features include:

* Use of the JSON+HAL (Hypertext Application Language) lean hypermedia type

* Automatic detection and exposure of result set relationships as HAL C<_links>

* Supports safe robust multi-related-record CRUD transactions

* Built on the strong foundations of [Web::Machine](https://metacpan.org/pod/Web::Machine),
[Path::Router](https://metacpan.org/pod/Path::Router) and [Plack](https://metacpan.org/pod/Plack)

* Built as fine-grained roles for maximum reusability and extensibility

* A built-in copy of the generic HAL API browser application

* An example PSGI file that gives you an instant web service for any DBIx::Class schema

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


# STATUS

The WebAPI::DBIC code has been in production use for over a year, however it's
only recently been open sourced (July 2014) so it's still lacking in
documentation, tests etc.

It's also likely to undergo a period of refactoring now there are more
developers contributing and the code is being applied to more domains.

Interested? Please get involved!

See HOW TO GET HELP in the WebAPI::DBIC documentation.


