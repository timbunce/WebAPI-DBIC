package WebAPI::DBIC::Resource::Role::DBIC;

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'id_for_key_values';
requires 'id_for_item';


has set => (
   is => 'rw',
   required => 1,
);

has writable => (
   is => 'ro',
);

has http_auth_type => (
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


# XXX perhaps shouldn't be a role, just functions, or perhaps a separate rendering object
# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # DateTimes
    return $data;
}


sub path_for_item {
    my ($self, $item) = @_;

    my $result_source = $item->result_source;

    my $id = $self->id_for_item($item);

    my $url = $self->uri_for(id => $id, result_class => $result_source->result_class)
        or confess sprintf("panic: no route found to result_class %s id %s (%s)",
            $result_source->result_class, $id, join(", ",
                map { "$_=".$item->get_column($_) } $result_source->primary_columns
            )
        );

    return $url;
}


# Uses the router to find the route that matches the given parameter hash
# returns nothing if there's no match, else
# returns the absolute url in scalar context, or in list context it returns
# the prefix (SCRIPT_NAME) and the relative url (from the router)
sub uri_for { ## no critic (RequireArgUnpacking)
    my $self = shift; # %pk in @_

    my $url = $self->router->uri_for(@_)
        or return;
    my $prefix = $self->request->env->{SCRIPT_NAME};

    return "$prefix/$url" unless wantarray;
    return ($prefix, $url);

}


sub render_item_into_body {
    my ($self, $item) = @_;

    # XXX ought to be a cloned request, with tweaked url/params?
    my $item_request = $self->request;

    # XXX shouldn't hard-code GenericItemDBIC here (should use router?)
    my $item_resource = WebAPI::DBIC::Resource::GenericItemDBIC->new(
        request => $item_request, response => $item_request->new_response,
        set => $self->set,
        item => $item,
        id => undef, # XXX dummy id
        prefetch => $self->prefetch,
        throwable => $self->throwable,
        #  XXX others? which and why? generalize
    );
    $self->response->body( $item_resource->to_json_as_hal );

    return;
}


sub _get_relationship_link_info {
    my ($result_class, $relname) = @_;
    my $rel = $result_class->relationship_info($relname);

    my $cond = $rel->{cond};

    # https://metacpan.org/pod/DBIx::Class::Relationship::Base#add_relationship
    if (ref $cond ne 'HASH') { # eg need to add support for CODE refs
        # we'll may end up silencing this warning till we can offer better support
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname cond value $cond not handled yet\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    if (keys %$cond > 1) {
        # if we loosen this constraint we might need to recheck it for some cases below
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since it has multiple conditions\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    # TODO support and test more kinds of relationships
    # TODO refactor

    if ($rel->{attrs}{accessor} eq 'multi') {

        # XXX are there any cases we're not dealing with here?

        Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};

        my $foreign_key = (keys %$cond)[0];
        $foreign_key =~ s/^foreign\.//
            or warn "Odd, no 'foreign.' prefix on $foreign_key ($result_class, $relname)";

        return {
            result_class => $rel->{source},
            id_fields => undef,
            id_filter => $foreign_key,
        };

    }

    # accessor is the inflation type (single/filter/multi)
    if ($rel->{attrs}{accessor} !~ /^(?: single | filter )$/x) {
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since we only support 'single' accessors (not $rel->{attrs}{accessor}) at the moment\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    # this is really a performance issue, so we could just warn
    # but for now we won't even warn and we'll see how it goes
    if ( 0 and not $rel->{attrs}{is_foreign_key_constraint}) {
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since we only support foreign key constraints at the moment\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    my $fieldname = (values %$cond)[0]; # first and only value
    $fieldname =~ s/^self\.// if $fieldname;

    if (not $fieldname) {
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since we can't determine a fieldname (@{[ %$cond ]})\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    return {
        result_class => $rel->{source},
        id_fields => [ $fieldname ],
    };
}


sub render_item_as_hal_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    my $itemurl = $self->path_for_item($item);
    $data->{_links}{self} = {
        href => $self->add_params_to_url($itemurl, {}, {})->as_string,
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        next if $prefetch eq 'self';
        my $subitem = $item->$prefetch();
        # XXX perhaps render_item_as_hal_hash but requires cloned WM, eg without prefetch
        # If we ever do render_item_as_hal_hash then we need to ensure that "a link
        # inside an embedded resource implicitly relates to that embedded
        # resource and not the parent."
        # See http://blog.stateless.co/post/13296666138/json-linking-with-hal
        $data->{_embedded}{$prefetch} = (defined $subitem)
            ? $self->render_item_as_plain_hash($subitem)
            : undef; # show an explicit null from a prefetch
    }

    my $curie = (0) ? "r" : ""; # XXX we don't use CURIE syntax yet

    # add links for relationships
    my $result_class = $item->result_class;
    for my $relname ($result_class->relationships) {

        # XXX much of this relation selection logic could be pre-calculated and cached
        #Dwarn
        my $rel_link_info = _get_relationship_link_info($result_class, $relname)
            or next;

        my @uri_for_args;
        if ($rel_link_info->{id_fields}) { # link to an item (1-1)
            my $id = $self->id_for_key_values(@{$data}{ @{ $rel_link_info->{id_fields} } });
            next if not defined $id; # no link because value is null
            push @uri_for_args, id => $id;
        }

        my $dst_class = $rel_link_info->{result_class} or die "panic";
        push @uri_for_args, result_class => $dst_class;

        my $linkurl = $self->uri_for( @uri_for_args );

        if (not $linkurl) {
            warn "Result source $dst_class has no resource uri in this app so relations (like $result_class $relname) won't have _links for it.\n"
                unless our $warn_once->{"$result_class $relname $dst_class"}++;
            next;
        }

        my %params;
        $params{ "me.".$rel_link_info->{id_filter} } = $self->id_for_item($item)
            if $rel_link_info->{id_filter};

        my $href = $self->add_params_to_url(
            $linkurl,
            {},
            \%params,
        );

        $data->{_links}{ ($curie?"$curie:":"") . $relname} = { href => $href->as_string };
    }
    if ($curie) {
       $data->{_links}{curies} = [{
         name => $curie,
         href => "http://docs.acme.com/relations/{rel}", # XXX
         templated => JSON->true,
       }];
   }

    return $data;
}


sub router {
    return shift->request->env->{'plack.router'};
}


sub add_params_to_url { # XXX this is all a bit suspect
    my ($self, $base, $passthru_params, $override_params) = @_;
    $base || croak "no base";

    my $req_params = $self->request->query_parameters;
    my @params = (%$override_params);

    # XXX turns 'foo~json' into 'foo', and 'me.bar' into 'me'.
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


1;
