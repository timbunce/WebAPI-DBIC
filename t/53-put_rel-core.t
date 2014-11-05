#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use Devel::Dwarn;

use lib "t/lib";
use TestDS;
use WebAPI::DBIC::WebApp;

use Test::Roo;
with 'TestRole::Schema';

after setup => sub {
    my ($self) = @_;
    $self->load_fixtures(qw(basic));
};


test "===== Update a resource and related resources via PUT =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;

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

run_me();

done_testing();
