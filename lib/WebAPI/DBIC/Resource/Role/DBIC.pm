package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

use Carp;
use Scalar::Util qw(blessed);
use Devel::Dwarn;
use JSON ();


has set => (
   is => 'rw',
   required => 1,
);

has writable => (
   is => 'ro',
);

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
    my $result_source = $item->result_source;

    my %pk = map { $_ => $item->get_column($_) } $result_source->primary_columns;
    my $url = $self->uri_for(%pk, result_class => $result_source->result_class)
        or die "panic: no route to @{[ %pk ]} ".$result_source->result_class;

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
            my $item_result_class = $item->result_class;
            warn "Result source $rel->{source} has no resource uri in this app so relations (like $item_result_class $relname) won't have _links for it.\n"
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
            field => $1,
            foo => "$1: $2",
        };
    }
    # handle exceptions from Params::Validate
    elsif ($exception =~ /The '(\w+)' parameter \(.*?\) to (\S+) did not pass/) {
        $error_data = {
            status => 400,
            field => $1,
            message => $line1,
        };
    }

    warn "finish_request is handling exception: $line1 (@{[ %{ $error_data||{} } ]})\n";

    if ($error_data) {
        $error_data->{_embedded}{exceptions}[0]{exception} = "$exception" # stringify
            unless $ENV{TL_ENVIRONMENT} eq 'production'; # don't leak info
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
