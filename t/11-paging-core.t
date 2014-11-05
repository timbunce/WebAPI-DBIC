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
        %artist = map { $_->{artistid} => $_ } @$data;
    };

    for my $rows_param (1,2,3) {
        note "rows $rows_param, page 1 implied";
        test_psgi $app, sub {
            my $data = dsresp_ok(shift->(dsreq( GET => "/artist?rows=$rows_param" )));
            is @$data, $rows_param, "correct number of rows";

            eq_or_diff $data->[$_], $artist{$_+1}, 'record matches'
                for 0..$rows_param-1;
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

                eq_or_diff $data->[$_], $artist{ (($page-1)*2) + $_ + 1}, 'record matches'
                    for 0..1;
            };
        }
        ;
    }
    ;

};


run_me();
done_testing();


sub _url_edit {
    my ($url, $param, $value) = @_;
    # we do this the hacky way to keep the order of params
    $url =~ s/(\?|&)$param=(?:.*?)(&|$)/$1$param=$value$2/;
    return $url;
}
