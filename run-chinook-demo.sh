#!/bin/sh -xe

# Fetch the Chinook sample database and corresponding DBIx::Class schema
# See http://chinookdatabase.codeplex.com
# and https://github.com/IntelliTree/RA-ChinookDemo
#
# Based on https://gist.github.com/vanstyn/c2e42944f8453a910ccf

[ -d RA-ChinookDemo ] || git clone https://github.com/IntelliTree/RA-ChinookDemo.git
# start fresh each time - wiping out any previous changes
(cd RA-ChinookDemo && git clean -dfx)
cpanm MooseX::MarkAsMethods

export PERLLIB=RA-ChinookDemo/lib
export WEBAPI_DBIC_SCHEMA=RA::ChinookDemo::DB
export WEBAPI_DBIC_HTTP_AUTH_TYPE=none
export WEBAPI_DBIC_WRITABLE=1

export DBI_DSN='dbi:SQLite:RA-ChinookDemo/chinook.db'

plackup -Ilib webapi-dbic-any.psgi

