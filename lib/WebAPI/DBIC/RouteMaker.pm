package WebAPI::DBIC::RouteMaker;

=head1 NAME

WebAPI::DBIC::RouteMaker - Make routes for resultsets

=cut

use Moo;

use Module::Runtime qw(use_module);
use Sub::Util qw(subname);
use Scalar::Util qw(blessed);
use Carp qw(croak confess);
use Devel::Dwarn;

use namespace::clean -except => [qw(meta)];
use MooX::StrictConstructor;

use WebAPI::DBIC::Route;


has schema => (is => 'rw');

has resource_class_for_item        => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItem');
has resource_class_for_item_invoke => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItemInvoke');
has resource_class_for_set         => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericSet');
has resource_class_for_set_invoke  => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericSetInvoke');
has resource_default_args          => (is => 'ro', default => sub { {} });
has resource_extra_roles           => (is => 'ro', default => sub { [] });

has type_namer => (
    is => 'ro',
    default => sub {
        require WebAPI::DBIC::TypeNamer;
        return WebAPI::DBIC::TypeNamer->new
    },
);


sub _qr_names {
    my $names_r = join "|", map { quotemeta $_ } @_ or confess "panic";
    return qr/^(?:$names_r)$/x;
}


sub make_routes_for_resultset {
    my ($self, $path, $set, %opts) = @_;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "Auto routes for /%s => %s\n",
            $path, $set->result_class;
    }

    my @routes;

    push @routes, $self->make_routes_for_set($path, $set, {
        invokable_methods => delete($opts{invokeable_methods_on_set}),
    });

    push @routes, $self->make_routes_for_item($path, $set, {
        invokable_methods => delete($opts{invokeable_methods_on_item})
    });

    croak "Unrecognized options: @{[ keys %opts ]}"
        if %opts;

    return @routes;
}


sub make_routes_for_item {
    my ($self, $path, $set, $opts) = @_;
    $opts ||= {};
    my $methods = $opts->{invokable_methods};

    use_module $self->resource_class_for_item;
    my $id_unique_constraint_name = $self->resource_class_for_item->id_unique_constraint_name;
    my $key_fields = { $set->result_source->unique_constraints }->{ $id_unique_constraint_name };

    unless ($key_fields) {
        warn sprintf "/%s/:id route skipped because %s has no '$id_unique_constraint_name' constraint defined\n",
            $path, $set->result_class;
        return;
    }

    # id fields have sequential numeric names
    # so .../:1 for a resource with a single key field
    # and .../:1/:2/:3 etc for a resource with  multiple key fields
    my $item_path_spec = join "/", map { ":$_" } 1 .. @$key_fields;

    my $resource_class_for_item = 
        $self->adapt_resource_class($self->resource_class_for_item);
    my $resource_class_for_item_invoke = 
        $self->adapt_resource_class($self->resource_class_for_item_invoke);

    my @routes;

    push @routes, WebAPI::DBIC::Route->new( # item
        path => "$path/$item_path_spec",
        resource_class => $resource_class_for_item,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
            type_namer => $self->type_namer,
        },
    );

    # XXX temporary hack just for testing
    push @$methods, 'get_column'
        if $set->result_class eq 'TestSchema::Result::Artist';

    push @routes, WebAPI::DBIC::Route->new( # method call on item
        path => "$path/$item_path_spec/invoke/:method",
        validations => { method => _qr_names(@$methods), },
        resource_class => $resource_class_for_item_invoke,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
            type_namer => $self->type_namer,
        },
    ) if $methods && @$methods;

    return @routes;
}


sub make_routes_for_set {
    my ($self, $path, $set, $opts) = @_;
    $opts ||= {};
    my $methods = $opts->{invokable_methods};

    my $resource_class_for_set = 
        $self->adapt_resource_class($self->resource_class_for_set);
    my $resource_class_for_set_invoke = 
        $self->adapt_resource_class($self->resource_class_for_set_invoke);

    my @routes;
   
    push @routes, WebAPI::DBIC::Route->new(
        path => $path,
        resource_class => $resource_class_for_set,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
            type_namer => $self->type_namer,
        },
    );

    push @routes, WebAPI::DBIC::Route->new( # method call on set
        path => "$path/invoke/:method",
        validations => { method => _qr_names(@$methods) },
        resource_class => $resource_class_for_set_invoke,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
            type_namer => $self->type_namer,
        },
    ) if $methods && @$methods;

    return @routes;
}

sub adapt_resource_class {
    my ($self, $resource_class) = @_;

    if(@{ $self->resource_extra_roles }) {
        $resource_class = Role::Tiny->create_class_with_roles(
            $resource_class, 
            @{ $self->resource_extra_roles }
        );
        ## Workaround Role::Tiny not setting %INC, which confuses use_module later.
        $INC{Module::Runtime::module_notional_filename($resource_class)} = __FILE__;

    }

    return $resource_class;
}

sub make_root_route {
    my $self = shift;
    my $root_route = WebAPI::DBIC::Route->new(
        path => '',
        resource_class => 'WebAPI::DBIC::Resource::GenericRoot',
        resource_args  => {
            %{ $self->resource_default_args },
            type_namer => $self->type_namer,
        },
    );
    return $root_route;
}



sub make_routes_for {
    my ($self, $route_spec) = @_;

    # route_spec:
    #   'People'
    #   { set => 'People', path => undef }
    #   { set => $self->set->resultset('People'), path => undef }
    #   WebAPI::DBIC::Route->new(...) - gets used directly

    my %opts;

    if (ref $route_spec eq 'HASH') {
        # invokeable_methods_on_item => undef,
        # invokeable_methods_on_set  => undef,
        %opts = %$route_spec;
        $route_spec = delete $opts{set};
    }

    if (not ref $route_spec) {
        my $schema = $self->schema
            or croak "Can't convert '$route_spec' to a resultset because schema isn't set in $self";
        $route_spec = $schema->resultset($route_spec);
    }
    elsif ($route_spec->does('WebAPI::DBIC::Resource::Role::Route')) {
        return $route_spec; # is already a route
    }

    unless (blessed $route_spec and $route_spec->isa('DBIx::Class::ResultSet')) {
        croak "Don't know how to convert '$route_spec' into to a DBIx::Class::ResultSet or WebAPI::DBIC::Resource::Role::Route";
    }

    my $path = delete($opts{path}) || $self->type_namer->type_name_for_resultset($route_spec);

    return $self->make_routes_for_resultset($path, $route_spec, %opts);
}


1;
