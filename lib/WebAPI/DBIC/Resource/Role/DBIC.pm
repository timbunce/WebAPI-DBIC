package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

use Carp;
use Devel::Dwarn;

has prefetch => (
    is => 'rw',
    default => sub { {} },
);


# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # DateTimes
    return $data;
}


sub path_for_item {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain($item);
    my %pk = map { $_ => $item->get_column($_) } $item->result_source->primary_columns;
    my $itemurl = $self->router->uri_for(
        %pk, result_class => $item->result_source->result_class,
    ) or die "panic: no route to @{[ %pk ]} ".$item->result_source->result_class;

    return $itemurl;
}


sub render_item_as_hal {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain($item);
    my $itemurl = $self->path_for_item($item);

    $data->{_links}{self} = {
        href => $self->mk_link_url("/$itemurl", {}, {})->as_string,
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        next if $prefetch eq 'self';
        # XXX perhaps render_item_as_hal but requires cloned WM, eg without prefetch
        $data->{_embedded}{$prefetch} = $self->render_item_as_plain($item->$prefetch);
    }

    # add links for relationships
    # XXX much of this should be cached
    for my $relname ($item->result_class->relationships) {
        my $rel = $item->result_class->relationship_info($relname);

        # XXX support other types of relationships
        # specifically multi's that would map to collection urls
        # with me.foo=X query parameters
        # see also https://example.com/default.asp?23010
        my $fieldname = $rel->{cond}{"foreign.id"};
        $fieldname =~ s/^self\.// if $fieldname;
        next unless $rel->{attrs}{accessor} eq 'single'
                and $rel->{attrs}{is_foreign_key_constraint}
                and $fieldname
                and defined $data->{$fieldname};

        my $linkurl = $self->router->uri_for(
            result_class => $rel->{source},
            id           => $data->{$fieldname},
        );
        if (not $linkurl) {
            warn "No path for $relname ($rel->{source})"
                unless our $warn_once->{"$relname $rel->{source}"}++;
            next;
        }
        $data->{_links}{"relation:$relname"} = {
            href => $self->mk_link_url("/$linkurl", {}, {})->as_string
        };
    }

    return $data;
}

sub router {
    return shift->request->env->{'plack.router'};
}

sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain($_) } $set->all ];
    return $set_data;
}


sub mk_link_url {
    my ($self, $base, $passthru_params, $override_params) = @_;
    $base || croak "no base";

    my $req_params = $self->request->query_parameters;
    my @params = (%$override_params);

    # turns 'foo~json' into 'foo', and 'me.bar' into 'me'.
    my %override_param_basenames = map { (split(/\W/,$_,2))[0] => 1 } keys %$override_params;

    # TODO this logic should live elsewhere
    for my $param (sort keys %$req_params) {

        # ignore request params that we have an override for
        my $param_basename = (split(/\W/,$param,2))[0];
        next if defined $override_param_basenames{$param_basename};

        next unless $passthru_params->{$param_basename};

        push @params, $param => $req_params->get($param);
    }
    my $uri = URI->new($base);
    $uri->query_form(@params);
    return $uri;
}

sub _hal_page_links {
    my ($self, $set, $base, $page_items, $total_items) = @_;
    return () unless $set->is_paged;

    # XXX we break encapsulation here, sadly, because calling
    # $set->pager->current_page triggers a "select count(*)".
    # XXX When we're using a later version of DBIx::Class we can use this:
    # https://metacpan.org/source/RIBASUSHI/DBIx-Class-0.08208/lib/DBIx/Class/ResultSet/Pager.pm
    # and do something like $rs->pager->total_entries(sub { 99999999 })
    my $rows = $set->{attrs}{rows} or die "panic: rows not set";
    my $page = $set->{attrs}{page} or die "panic: page not set";

    my $url = $self->mk_link_url($base, { with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => { href => $linkurl.($page) };
    push @link_kvs, next  => { href => $linkurl.($page+1) }
        if $page_items == $rows;
    push @link_kvs, prev  => { href => $linkurl.($page-1) }
        if $page > 1;
    push @link_kvs, first => { href => $linkurl.1 }
        if $page > 1;
    push @link_kvs, last  => { href => $linkurl.$set->pager->last_page }
        if $total_items and $page != $set->pager->last_page;

    return @link_kvs;
}

sub render_set_as_hal {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_hal($_) } $set->all ];
    my $path = $self->request->env->{'plack.router.match'}->{path};

    my $total_items;
    if (($self->request->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
    }

    my $data = {
        _embedded => {
            $path => $set_data,
        },
        _links => {
            $self->_hal_page_links($set, "/$path", scalar @$set_data, $total_items),
        }
    };
    $data->{_meta}{count} = $total_items
        if defined $total_items;

    return $data;
}


sub finish_request {
    my ($self, $metadata) = @_;

    my $exception = $metadata->{'exception'};
    return unless $exception;

    (my $line1 = $exception) =~ s/\n.*//ms;
    warn "finish_request - handling exception $line1\n";

    my $error_data;
    # ... DBD::Pg::st execute failed: ERROR:  column "nonesuch" does not exist
    if ($exception =~ m/DBD::Pg.*? failed:.*? column "(.*?)" (.*)/) {
        $error_data = {
            status => 400,
            foo => "$1: $2",
        };
    }

    if ($error_data) {
        $error_data->{_embedded}{exceptions}[0]{exception} = "$exception" # stringify
            unless $ENV{TL_ENVIRONMENT} eq 'production';
        $error_data->{status} ||= 500;
        # create response
        my $json = JSON->new->ascii->pretty;
        my $response = $self->response;
        $response->status($error_data->{status});
        my $body = $json->encode($error_data);
        $response->body($body);
        $response->content_length(length $body);
        $response->content_type('application/hal+json');
    }
}


1;
