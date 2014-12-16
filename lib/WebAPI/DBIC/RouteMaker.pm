package WebAPI::DBIC::RouteMaker;

use Moo;

use Module::Runtime qw(use_module);
use Sub::Util qw(subname);
use WebAPI::DBIC::Route;
use String::CamelCase qw(camelize decamelize);
use Lingua::EN::Inflect::Number qw(to_S to_PL);
use Carp qw(croak confess);

use Devel::Dwarn;

use namespace::clean;


has schema => (is => 'ro', required => 1);
has resource_default_args => (is => 'ro', default => sub { {} });
has resource_class_for_item        => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItem');
has resource_class_for_item_invoke => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItemInvoke');
has routes => (
    is => 'ro',
    lazy => 1,
    default => sub { [ shift->schema->sources ] },
);

# specify what information should be used to define the url path/type of a schema class
# (result_name is deprecated and only supported for backwards compatibility)
has type_name_from  => (is => 'ro', default => 'source_name'); # 'source_name', 'result_name'

# how type_name_from should be inflected
has type_name_inflect => (is => 'ro', default => 'original'); # 'original', 'singular', 'plural'

# how type_name_from should be capitalized
has type_name_style => (is => 'ro', default => 'decamelize'); # 'original', 'camelize', 'decamelize'


sub type_name_for_schema_source {
    my ($self, $source_name) = @_;

    my $type_name;
    if ($self->type_name_from eq 'source_name') {
        $type_name = $source_name;
    }
    elsif ($self->type_name_from eq 'result_name') { # deprecated
        my $result_source = $self->schema->source($source_name);
        $type_name = $result_source->name; # eg table name
        $type_name = $$type_name if ref($type_name) eq 'SCALAR';
    }
    else {
        confess "Invalid type_name_from: ".$self->type_name_from;
    }

    if ($self->type_name_inflect eq 'singular') {
        $type_name = to_S($type_name);
    }
    elsif ($self->type_name_inflect eq 'plural') {
        $type_name = to_PL($type_name);
    }
    else {
        confess "Invalid type_name_inflect: ".$self->type_name_inflect
            unless $self->type_name_inflect eq 'original';
    }

    if ($self->type_name_style eq 'decamelize') {
        $type_name = decamelize($type_name);
    }
    elsif ($self->type_name_style eq 'camelize') {
        $type_name = camelize($type_name);
    }
    else {
        confess "Invalid type_name_style: ".$self->type_name_from
            unless $self->type_name_style eq 'original';
    }

    return $type_name;
}


sub _qr_names {
    my $names_r = join "|", map { quotemeta $_ } @_ or confess "panic";
    return qr/^(?:$names_r)$/x;
}


sub get_routes_for_resultset {
    my ($self, $path, $set, %opts) = @_;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "Auto routes for /%s => %s\n",
            $path, $set->result_class;
    }

    my @routes;

    push @routes, $self->get_routes_for_set($path, $set, {
        invokable_methods => delete($opts{invokeable_methods_on_set}),
    });

    push @routes, $self->get_routes_for_item($path, $set, {
        invokable_methods => delete($opts{invokeable_methods_on_item})
    });

    croak "Unrecognized options: @{[ keys %opts ]}"
        if %opts;

    return @routes;
}


sub get_routes_for_item {
    my ($self, $path, $set, $opts) = @_;
    $opts ||= {};
    my $methods = $opts->{invokable_methods};

    use_module $self->resource_class_for_item;
    my $id_unique_constraint_name = $self->resource_class_for_item->id_unique_constraint_name;
    my $key_fields = { $set->result_source->unique_constraints }->{ $id_unique_constraint_name };

    unless ($key_fields) {
        warn sprintf "/%s/:id route skipped because %s has no $id_unique_constraint_name constraint defined\n",
            $path, $set->result_class;
        return;
    }

    # id fields have sequential numeric names
    # so .../:1 for a resource with a single key field
    # and .../:1/:2/:3 etc for a resource with  multiple key fields
    my $item_path_spec = join "/", map { ":$_" } 1 .. @$key_fields;

    my @routes;

    push @routes, WebAPI::DBIC::Route->new( # item
        path => "$path/$item_path_spec",
        resource_class => $self->resource_class_for_item,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
        },
    );

    # XXX temporary hack just for testing
    push @$methods, 'get_column'
        if $set->result_class eq 'TestSchema::Result::Artist';

    push @routes, WebAPI::DBIC::Route->new( # method call on item
        path => "$path/$item_path_spec/invoke/:method",
        validations => { method => _qr_names(@$methods), },
        resource_class => $self->resource_class_for_item_invoke,
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
        },
    ) if $methods && @$methods;

    return @routes;
}


sub get_routes_for_set {
    my ($self, $path, $set, $opts) = @_;
    $opts ||= {};
    my $methods = $opts->{invokable_methods};

    my @routes;
   
    push @routes, WebAPI::DBIC::Route->new(
        path => $path,
        resource_class => 'WebAPI::DBIC::Resource::GenericSet',
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
        },
    );

    push @routes, WebAPI::DBIC::Route->new( # method call on set
        path => "$path/invoke/:method",
        validations => { method => _qr_names(@$methods) },
        resource_class => 'WebAPI::DBIC::Resource::GenericSetInvoke',
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
        },
    ) if $methods && @$methods;

    return @routes;
}


sub get_root_route {
    my $self = shift;
    my $root_route = WebAPI::DBIC::Route->new(
        path => '',
        resource_class => 'WebAPI::DBIC::Resource::GenericRoot',
        resource_args  => {},
    );
    return $root_route;
}



sub routes_for {
    my ($self, $route_spec) = @_;

    if (not ref $route_spec) {
        $route_spec = $self->schema->resultset($route_spec);
    }
    elsif ($route_spec->does('WebAPI::DBIC::Resource::Role::Route')) {
        return $route_spec; # is already a route
    }

    # $route_spec is now a ResultSet
    my $source_name = $route_spec->result_source->name; # XXX wrong
    $source_name = $$source_name if ref($source_name) eq 'SCALAR';

    my $type_name = $self->type_name_for_schema_source($source_name);

    return $self->get_routes_for_resultset($type_name, $route_spec);
}


1;
