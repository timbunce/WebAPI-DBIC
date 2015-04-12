#!/usr/bin/env perl


use lib "t/lib";
use TestKit;
use TestDS_ActiveModel;

fixtures_ok [qw/basic/];

subtest "===== Create a resource via POST =====" => sub {
    my ($self) = @_;

    my $app = TestWebApp->new({
        routes => [ map( Schema->source($_), 'Track') ],
    })->to_psgi_app;

    run_request_spec_tests($app, \*DATA);

    my $orig_item;
    my $orig_location;

    # POST to the set to create a Track to edit (on an existing CD)
    test_psgi $app, sub {
        my $res = shift->(dsreq_activemodel( POST => "/track?prefetch=self", [], {
            track => {
                title => "Just One More (remix)",
                position => 42,
                cd => 2,
            },
        }));
        ($orig_location, $orig_item) = dsresp_created_ok($res);
    };

    note "recheck data as a separate request";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq_activemodel( GET => "/track/$orig_item->{track}->[0]->{trackid}?prefetch=disc")))->{track}->[0];
        ok $data->{trackid}, 'has trackid assigned';
        is $data->{title}, "Just One More (remix)";
        is $data->{position}, $orig_item->{track}->[0]->{position}, 'has same position assigned';
    };

    test_psgi $app, sub {
        dsresp_ok(shift->(dsreq_activemodel( DELETE => "/track/$orig_item->{track}->[0]->{trackid}")), 204);
    };

};

done_testing();

__DATA__
Config:
Accept: application/json
Content-Type: application/json

Name: POST to the set to create a Track (on an existing CD)
POST /track?prefetch=self
{ "track": { "title":"Just One More", "position":4200, "cd":2 } }

Name: delete the track we just added
DELETE /track/19
