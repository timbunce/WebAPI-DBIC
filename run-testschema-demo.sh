#!/bin/sh -xe

export WEBAPI_DBIC_SCHEMA=DummyLoadedSchema
export WEBAPI_DBIC_HTTP_AUTH_TYPE=none
export WEBAPI_DBIC_WRITABLE=1

plackup -Ilib -It/lib webapi-dbic-any.psgi

