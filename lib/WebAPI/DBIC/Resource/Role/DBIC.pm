package WebAPI::DBIC::Resource::Role::DBIC;

=head1 NAME

WebAPI::DBIC::Resource::Role::DBIC - a role with core methods for DBIx::Class resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'uri_for';
requires 'throwable';
requires 'request';
requires 'response';
requires 'get_url_for_item_relationship';
requires 'id_kvs_for_item';


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


# XXX perhaps shouldn't be a role, just functions, or perhaps a separate rendering object
# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    my $data = { $item->get_inflated_columns };
    # DateTimes
    return $data;
}


sub path_for_item {
    my ($self, $item) = @_;

    my $result_source = $item->result_source;

    my @id_kvs = $self->id_kvs_for_item($item);

    my $url = $self->uri_for( @id_kvs, result_class => $result_source->result_class)
        or confess sprintf("panic: no route found to result_class %s (%s)",
            $result_source->result_class, join(", ", @id_kvs)
        );

    return $url;
}


sub render_item_into_body {
    my ($self, $item) = @_;

    # XXX ought to be a cloned request, with tweaked url/params?
    my $item_request = $self->request;

    # XXX shouldn't hard-code GenericItem here (should use router?)
    my $item_resource = WebAPI::DBIC::Resource::GenericItem->new(
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
    for my $relname ($item->result_class->relationships) {

        my $url = $self->get_url_for_item_relationship($item, $relname)
            or next;

        $data->{_links}{ ($curie?"$curie:":"") . $relname} = { href => $url->as_string };
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
