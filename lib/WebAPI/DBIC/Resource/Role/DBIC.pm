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

has type_namer => (
   is => 'ro',
);

has prefetch => (
    is => 'rw',
    default => sub { [] },
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

    my @id_kvs = $self->id_kvs_for_item($item);

    my $url = $self->uri_for( @id_kvs, result_class => $result_source->result_class)
        or confess sprintf("panic: no route found to result_class %s (%s)",
            $result_source->result_class, join(", ", @id_kvs)
        );

    return $url;
}



# used for recursive rendering
sub web_machine_resource {
    my ($self, %resource_args) = @_;

    # XXX shouldn't hard-code GenericItem here (should use router?)
    my $resource_class = ($resource_args{item})
        ? 'WebAPI::DBIC::Resource::GenericItem'
        : 'WebAPI::DBIC::Resource::GenericSet';

    my $resource = $resource_class->new(
        request  => $self->request,
        response => $self->request->new_response,
        throwable => $self->throwable,
        prefetch  => [], # don't propagate prefetch by default
        set => undef,
        id => undef,
        #  XXX others? which and why? generalize
        %resource_args
    );

    return $resource;
}


sub render_item_into_body {
    my ($self, %resource_args) = @_;

    my $item_resource = $self;
    # if an item has been specified then we assume that it's not $self->item
    # and probably relates to a different resource, so we create one for it
    # that doesn't have the request params set, eg prefetch
    if ($resource_args{item}) {
        $item_resource = $self->web_machine_resource( %resource_args );
    }

    # XXX temporary hack
    my $body;
    if ($self->request->headers->header('Accept') =~ /hal\+json/) {
        $body = $item_resource->to_json_as_hal;
    }
    else {
        $body = $item_resource->to_json_as_plain;
    }

    $self->response->body($body);

    return;
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
