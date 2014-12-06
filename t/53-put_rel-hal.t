#!/usr/bin/env perl


use lib "t/lib";
use TestKit;

fixtures_ok [qw/basic/];

subtest "===== Update a resource and related resources via PUT =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => Schema,
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

    my $orig_item;
    my $orig_location;

    # POST to the set to create a Track to edit (on an existing CD)
    test_psgi $app, sub {
        my $res = shift->(dsreq( POST => "/track?prefetch=self", [], {
            title => "Just One More",
            position => 42,
            cd => 2,
        }));
        ($orig_location, $orig_item) = dsresp_created_ok($res);
    };

    # PUT to the item to update the item and the related CD
    test_psgi $app, sub {
        my $res = shift->(dsreq( PUT => "/track/$orig_item->{trackid}?prefetch=self,disc", [], {
            title => "Just One More (remix)",
        }));
        my $data = dsresp_ok($res);

        is ref $data, 'HASH', 'return data';
        ok $data->{trackid}, 'has trackid assigned';
        is $data->{title}, "Just One More (remix)";
        is $data->{position}, $orig_item->{position}, 'has same position assigned';
    };

    note "recheck data as a separate request";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/track/$orig_item->{trackid}?prefetch=self,disc")));
        ok $data->{trackid}, 'has trackid assigned';
        is $data->{title}, "Just One More (remix)";
        is $data->{position}, $orig_item->{position}, 'has same position assigned';
    };

    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq( DELETE => "/track/$orig_item->{trackid}")), 204);
    };

};

done_testing();

__DATA__
Config:
Accept: application/hal+json,application/json

Name: POST to the set to create a Track to edit (on an existing CD)
POST /track?prefetch=self
{ "title":"Just One More", "position":4200, "cd":2 }

Name: update the title (19 hardwired for now) and prefetch self and disc
PUT /track/19?prefetch=self,disc
{ "title":"Just One More (remix)" }

Name: update the track id (primary key)
# TODO this ought to return a Location header
PUT /track/19?prefetch=self
{ "trackid":1900 }

Name: delete the track we just added
DELETE /track/1900
