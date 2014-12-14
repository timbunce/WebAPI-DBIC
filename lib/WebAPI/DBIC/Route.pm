package WebAPI::DBIC::Route;

=head1 NAME

WebAPI::DBIC::Route - A URL path to a WebAPI::DBIC Resource

=head1 DESCRIPTION

=cut

use Moo;

use Module::Runtime qw(use_module);


has path => (
    is => 'ro',
    required => 1,
);

has resource_class => (
    is => 'ro',
    required => 1,
);

has resource_args => (
    is => 'ro',
    required => 1,
);

has route_defaults => (
    is => 'ro',
    default => sub { {} },
);

has validations => (
    is => 'ro',
    default => sub { {} },
);


sub BUILD {
    my $self = shift;

    my $resource_class = $self->resource_class;
    my $route_defaults = $self->route_defaults;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        (my $class = $resource_class) =~ s/^WebAPI::DBIC::Resource//;
        warn sprintf "/%s => %s (%s)\n",
            $self->path, $class,
            join(' ', map { "$_=$route_defaults->{$_}" } keys %$route_defaults);
    }

    use_module $resource_class;

    if (my $set = $self->resource_args->{set}) {

        # we use the 'result_class' key in the route_defaults to lookup the route
        # for a given result_class
        $route_defaults->{result_class} = $set && $set->result_class;
    }
    else {
        warn sprintf "/%s resource_class %s has 'set' method but resource_args does not include 'set'",
                $self->path, $resource_class
            if $resource_class->can('set');
    }

    return;
}


sub as_add_route_args {
    my $self = shift;

    my $resource_class = $self->resource_class;

    # introspect path to extract path param :names
    my $prr = Path::Router::Route->new(path => $self->path);
    my $path_var_names = [
        map { $prr->get_component_name($_) }
        grep { $prr->is_component_variable($_) }
        @{ $prr->components }
    ];

    # this logic ought to move into the resource_class
    my $resource_args_from_route = sub {
        # XXX we could try to generate more efficient code here
        my $req = shift;
        my $args = shift;
        for (@$path_var_names) { #in path param name order
            if (m/^[0-9]+$/) { # an id field
                $args->{id}[$_-1] = shift @_;
            }
            else {
                $args->{$_} = shift @_;
            }
        }
    };


    # this sub acts as the interface between the router and
    # the Web::Machine instance handling the resource for that url path
    my $target = sub {
        my $request = shift; # URL args from router remain in @_

        my %resource_args_from_params;
        # perform any required setup for this request & params in @_
        $resource_args_from_route->($request, \%resource_args_from_params, @_);

        warn sprintf "%s: running %s machine (@{[ keys %resource_args_from_params ]})\n",
                $self->path, $resource_class
            if $ENV{WEBAPI_DBIC_DEBUG};

        my $app = Web::Machine->new(
            resource => $resource_class,
            resource_args => [ %{$self->resource_args}, %resource_args_from_params ],
            tracing => $ENV{WEBAPI_DBIC_DEBUG},
        )->to_app;

        #local $SIG{__DIE__} = \&Carp::confess;
        #Dwarn
        my $resp = $app->($request->env);

        return $resp;
    };

    return (
        path        => $self->path,
        validations => $self->validations || {},
        defaults    => $self->route_defaults,
        target      => $target,
    );
}


1;
