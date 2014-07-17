#!/usr/bin/env perl

use Test::Most;
use Plack::Test;
use Test::HTTP::Response;
use JSON::MaybeXS;
use URI;
use URI::QueryParam;
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


local $SIG{__DIE__} = \&Carp::confess;

test "===== Paging =====" => sub {
    my ($self) = @_;

    my $app = WebAPI::DBIC::WebApp->new({
        schema => $self->schema,
    })->to_psgi_app;

    my %artist;

    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist" )));
        my $set = is_set_with_embedded_key($data, "artist", 2);
        %artist = map { $_->{artistid} => $_ } @$set;
        is ref $artist{$_}, "HASH", "/artist includes $_"
            for (1..3);
        ok $artist{1}{name}, "/artist data looks sane";
    };

    for my $rows_param (1,2,3) {
        note "rows $rows_param, page 1 implied";
        test_psgi $app, sub {
            my $data = dsresp_ok(shift->(dsreq( GET => "/artist?rows=$rows_param" )));
            my $set = is_set_with_embedded_key($data, "artist", $rows_param, $rows_param);

            eq_or_diff $set->[$_], $artist{$_+1}, 'record matches'
                for 0..$rows_param-1;

            is ref(my $links = $data->{_links}), 'HASH', "has _links hashref";
            is $links->{next}{href}, "/artist?rows=$rows_param&page=2", 'next link';
            is $links->{prev},  undef, 'should not have prev link';
            is $links->{first}, undef, 'should not have first link';
            is $links->{last},  undef, 'should not have last link';
        };
    };


    for my $with_count (0, 1) {
        for my $page (1,2) {
            note "page $page, with small rows param".($with_count ? " with count" : "");
            test_psgi $app, sub {
                my $url = "/artist?rows=2";
                $url .= "&with=count" if $with_count;
                $url .= "&page=$page";

                my $data = dsresp_ok(shift->(dsreq( GET => $url )));
                my $set = is_set_with_embedded_key($data, "artist", 2, 2);

                eq_or_diff $set->[$_], $artist{ (($page-1)*2) + $_ + 1}, 'record matches'
                    for 0..1;

                is ref(my $links = $data->{_links}), 'HASH', "has _links hashref";
                is $links->{next}{href}, _url_edit($url, page => $page+1), "next link of $url";
                if ($page == 1) {
                    is $links->{prev},  undef, 'should not have prev link';
                    is $links->{first}, undef, 'should not have first link';
                }
                else {
                    is $links->{prev}{href},  _url_edit($url, page=>$page-1), "prev link of $url";
                    is $links->{first}{href}, _url_edit($url, page=>1), "first link of $url";
                }
                if ($with_count) {
                    my $urlregex = quotemeta(_url_edit($url, page=>'')).'\d+';
                    like $links->{last}{href}, qr{$urlregex}, "should have last link of $url";
                }
                else {
                    is $links->{last}{href},  undef, "should not have last link of $url";
                }
            };
        }
        ;
    }
    ;

    note "me.* param pass-thru";
    test_psgi $app, sub {
        my $data = dsresp_ok(shift->(dsreq( GET => "/artist?me.artistid=1" )));
        my $set = is_set_with_embedded_key($data, "artist", 1);
        ok $data->{_links}{self}{href}, 'has $data->{_links}{self}{href}';
        my $uri = URI->new($data->{_links}{self}{href});
        is $uri->query_param('me.artistid'), 1, 'me.artistid param passed through'
            or Dwarn $data;
    };
};


run_me();
done_testing();


sub _url_edit {
    my ($url, $param, $value) = @_;
    # we do this the hacky way to keep the order of params
    $url =~ s/(\?|&)$param=(?:.*?)(&|$)/$1$param=$value$2/;
    return $url;
}
