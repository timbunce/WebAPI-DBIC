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
has router_class => (is => 'ro', builder => 1);
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


sub _build_router_class {
    require WebAPI::DBIC::Router;
    return 'WebAPI::DBIC::Router';
}

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


sub mk_generic_dbic_item_set_routes {
    my ($self, $path, $set, %opts) = @_;

    my $invokeable_on_set  = delete $opts{invokeable_on_set}  || [];
    my $invokeable_on_item = delete $opts{invokeable_on_item} || [];

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "Auto routes for /%s => %s\n",
            $path, $set->result_class;
    }

    my %resource_default_args = %{ $self->resource_default_args };
    $resource_default_args{set} = $set;

    my @routes;

    push @routes, WebAPI::DBIC::Route->new(
        path => $path,
        resource_class => 'WebAPI::DBIC::Resource::GenericSet',
        resource_args  => \%resource_default_args,
    );

    push @routes, $self->get_route_for_set_invoke_methods($path, $set, $invokeable_on_set);


    my $item_resource_class = 'WebAPI::DBIC::Resource::GenericItem'; # XXX
    use_module $item_resource_class;
    my $id_unique_constraint_name = $item_resource_class->id_unique_constraint_name;
    my $uc_fields = { $set->result_source->unique_constraints }->{ $id_unique_constraint_name };

    if ($uc_fields) {
        my @key_fields = @$uc_fields;
        my @idn_fields = 1 .. @key_fields;
        my $item_path_spec = join "/", map { ":$_" } @idn_fields;

        push @routes, WebAPI::DBIC::Route->new( # item
            path => "$path/$item_path_spec",
            resource_class => $item_resource_class,
            resource_args  => \%resource_default_args,
        );

        # XXX hack for testing
        push @$invokeable_on_item, 'get_column'
            if $set->result_class eq 'TestSchema::Result::Artist';

        push @routes, WebAPI::DBIC::Route->new( # method call on item
            path => "$path/$item_path_spec/invoke/:method",
            validations => {
                method => _qr_names(@$invokeable_on_item),
            },
            resource_class => 'WebAPI::DBIC::Resource::GenericItemInvoke',
            resource_args  => \%resource_default_args,
        ) if @$invokeable_on_item;
    }
    else {
        warn sprintf "/%s/:id route skipped because %s has no $id_unique_constraint_name constraint defined\n",
            $path, $set->result_class;
    }

    return @routes;
}


sub get_route_for_set_invoke_methods {
    my ($self, $path, $set, $methods) = @_;

    return unless @$methods;

    return WebAPI::DBIC::Route->new( # method call on set
        path => "$path/invoke/:method",
        validations => { method => _qr_names(@$methods) },
        resource_class => 'WebAPI::DBIC::Resource::GenericSetInvoke',
        resource_args  => {
            %{ $self->resource_default_args },
            set => $set,
        },
    );
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
    elsif ($route_spec->does('WebAPI::DBIC::Resource::Role::Router')) {
        return $route_spec;
    }


    # $route_spec is now a ResultSet
    my $source_name = $route_spec->result_source->name; # XXX wrong
    $source_name = $$source_name if ref($source_name) eq 'SCALAR';
    die Dwarn if ref $source_name;

    my $type_name = $self->type_name_for_schema_source($source_name);

    return $self->mk_generic_dbic_item_set_routes($type_name, $route_spec);
}


1;
__END__
