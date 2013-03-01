package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

use Devel::Dwarn;

# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

sub base_uri { # XXX hack - use the router
    my ($self) = @_;
    my $base = $self->request->env->{PATH_INFO};
    $base =~ s:^(/\w+).*:$1:;
    return $base;
}

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # FKs
    # DateTimes
    return $data;
}

sub render_item_as_hal {
    my ($self, $item) = @_;
    my $base = $self->base_uri;
    my $data = $self->render_item_as_plain($item);
    $data->{_links} = {
        self => { href => $base."/".$item->id }
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        my $key = $info->{key} or die "panic";
        # XXX perhaps render_item_as_hal but requires cloned WM, eg without prefetch
        $data->{_embedded}{$key} = $self->render_item_as_plain($item->$prefetch);
    }

    # add links for relationships
    # XXX much of this could be cached
    for my $relname ($item->result_class->relationships) {
        my $rel = $item->result_class->relationship_info($relname);
        my $fieldname = $rel->{cond}{"foreign.id"};
        $fieldname =~ s/^self\.// if $fieldname;
        next unless $rel->{attrs}{accessor} eq 'single'
                and $rel->{attrs}{is_foreign_key_constraint}
                and $fieldname
                and defined $data->{$fieldname};

        my $uri = $self->router->uri_for(
            result_class => $rel->{source},
            id           => $data->{$fieldname},
        );
        if (not $uri) {
            warn "No path for $relname ($rel->{source})"
                unless our $warn_once->{"$relname $rel->{source}"}++;
            next;
        }
        $data->{_links}{"relation:$relname"} = {
            href => "/$uri"
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

sub _hal_page_link_data {
    my ($self, $set, $base, $page) = @_;
    my $rows = $set->{attrs}{rows} or die "panic: rows not set";
    return {
        href => "$base?rows=$rows&page=$page",
    };
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

    my @link_kvs;
    push @link_kvs, next => $self->_hal_page_link_data($set, $base, $page+1)
        if $page_items == $rows;
    push @link_kvs, prev => $self->_hal_page_link_data($set, $base, $page-1)
        if $page > 1;
    push @link_kvs, first => $self->_hal_page_link_data($set, $base, 1)
        if $page > 1;
    push @link_kvs, last => $self->_hal_page_link_data($set, $base, $set->pager->last_page)
        if $total_items and $page != $set->pager->last_page;
    return @link_kvs;
}

sub render_set_as_hal {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_hal($_) } $set->all ];
    my $path = $self->request->env->{'plack.router.match'}->{path};
    my $base = $self->base_uri;

    my $total_items;
    if (($self->request->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
    }

    my $data = {
        _embedded => {
            $path => $set_data,
        },
        _links => {
            self => { href => "$base" },
            $self->_hal_page_links($set, $base, scalar @$set_data, $total_items),
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
