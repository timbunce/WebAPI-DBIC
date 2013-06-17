package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

use Carp;
use Scalar::Util qw(blessed);
use Devel::Dwarn;
use JSON;

has prefetch => (
    is => 'rw',
    default => sub { {} },
);

has throwable => (
    is => 'rw',
    required => 1,
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

    my %pk = map { $_ => $item->get_column($_) } $item->result_source->primary_columns;
    my $url = $self->uri_for(%pk, result_class => $item->result_source->result_class)
        or die "panic: no route to @{[ %pk ]} ".$item->result_source->result_class;

    return $url;
}

sub uri_for {
    my $self = shift; # %pk in @_

    my $url = $self->router->uri_for(@_)
        or return undef;
    my $prefix = $self->request->env->{SCRIPT_NAME};

    return "$prefix/$url" unless wantarray;
    return ($prefix, $url);

}


sub render_item_into_body {
    my ($self, $item) = @_;
    # XXX ought to be a cloned request, with tweaked url/params?
    my $item_request = $self->request;
    # XXX shouldn't hard-code GenericItemDBIC here
    my $item_resource = WebAPI::DBIC::Resource::GenericItemDBIC->new(
        request => $item_request, response => $item_request->new_response,
        set => $self->set,
        item => $item, id => undef, # XXX dummy id
        prefetch => $self->prefetch,
        throwable => $self->throwable,
        #  XXX others?
    );
    $self->response->body( $item_resource->to_json_as_hal );

    return;
}


sub render_item_as_hal {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain($item);

    my $itemurl = $self->path_for_item($item);
    $data->{_links}{self} = {
        href => $self->add_params_to_url($itemurl, {}, {})->as_string,
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        next if $prefetch eq 'self';
        my $subitem = $item->$prefetch();
        # XXX perhaps render_item_as_hal but requires cloned WM, eg without prefetch
        # If we ever do render_item_as_hal then we need to ensure that "a link
        # inside an embedded resource implicitly relates to that embedded
        # resource and not the parent."
        # See http://blog.stateless.co/post/13296666138/json-linking-with-hal
        $data->{_embedded}{$prefetch} = (defined $subitem)
            ? $self->render_item_as_plain($subitem)
            : undef; # show an explicit null from a prefetch
    }

    my $curie = (0) ? "r" : ""; # XXX we don't use CURIE syntax yet

    # add links for relationships
    # XXX much of this relation selection logic should be cached
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

        my $linkurl = $self->uri_for(
            result_class => $rel->{source},
            id           => $data->{$fieldname},
        );
        if (not $linkurl) {
            warn "No path for $relname ($rel->{source})"
                unless our $warn_once->{"$relname $rel->{source}"}++;
            next;
        }
        $data->{_links}{ ($curie?"$curie:":"") . $relname} = {
            href => $self->add_params_to_url($linkurl, {}, {})->as_string
        };
    }
    if ($curie) {
       $data->{_links}{curies} = [{
         name => $curie,
         href => "http://docs.acme.com/relations/{rel}", # XXX
         templated => JSON::true,
       }];
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


sub add_params_to_url {
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

    # XXX this self link this should probably be subtractive, ie include all
    # params by default except any known to cause problems
    my $url = $self->add_params_to_url($base, { distinct=>1, with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => {
        href => $linkurl.($page),
        title => $set->result_class,
    };
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

    # some params mean we're not returning resource representations
    # so render the contents of the _embedded set as plain JSON
    my $render_meth = ($self->param('distinct'))
        ? 'render_item_as_plain'
        : 'render_item_as_hal';
    my $set_data = [ map { $self->$render_meth($_) } $set->all ];

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
    }

    my ($prefix, $rel) = $self->uri_for(result_class => $self->set->result_class);
    my $data = {
        _embedded => {
            $rel => $set_data,
        },
        _links => {
            $self->_hal_page_links($set, "$prefix/$rel", scalar @$set_data, $total_items),
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

    if (blessed($exception) && $exception->can('as_psgi')) {
        my ($status, $headers, $body) = @{ $exception->as_psgi };
        $self->response->status($status);
        $self->response->headers($headers);
        $self->response->body($body);
        return;
    }

    #$exception->rethrow if ref $exception and $exception->can('rethrow');
    #die $exception if ref $exception;

    (my $line1 = $exception) =~ s/\n.*//ms;

    my $error_data;
    # ... DBD::Pg::st execute failed: ERROR:  column "nonesuch" does not exist
    if ($exception =~ m/DBD::Pg.*? failed:.*? column "?(.*?)"? (.*)/) {
        $error_data = {
            status => 400,
            foo => "$1: $2",
        };
    }

    warn "finish_request - handling exception '$line1' (@{[ %{ $error_data||{} } ]})\n";

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
