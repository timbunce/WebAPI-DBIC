package WebAPI::DBIC::WebApp;

use Moo;

use Module::Runtime qw(use_module);
use WebAPI::DBIC::Route;
use String::CamelCase qw(camelize decamelize);
use Lingua::EN::Inflect::Number qw(to_S to_PL);
use Carp qw(croak confess);
use JSON::MaybeXS qw(JSON);

use Devel::Dwarn;

use Web::Machine;

# pre-load some modules to improve shared memory footprint
require DBIx::Class::SQLMaker;

use namespace::clean;


has schema => (is => 'ro', required => 1);
has writable => (is => 'ro', default => 1);
has http_auth_type => (is => 'ro', default => 'Basic');
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

sub _build_auto_schema_routesets {
    my ($self) = @_;

    my @routes;
    for my $source_name ($self->schema->sources) {

        my $type_name = $self->type_name_for_schema_source($source_name);

        my %opts;
        # this is a hack just to enable testing, eg t/60-invoke-*.t
        push @{$opts{invokeable_on_item}}, 'get_column'
            if $self->schema->resultset($source_name)
                ->result_class =~ /^TestSchema::Result/;

        # these become args to mk_generic_dbic_item_set_routes
        my $set = $self->schema->resultset($source_name);
        push @routes, [ $type_name => $set, %opts ];
    }

    return \@routes;
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


sub mk_generic_dbic_item_set_routes {
    my ($self, $path, $set, %opts) = @_;

    # XXX might want to distinguish writable from non-writable (read-only) methods
    my $invokeable_on_set  = delete $opts{invokeable_on_set}  || [];
    my $invokeable_on_item = delete $opts{invokeable_on_item} || [];
    # disable all methods if not writable, for safety: (perhaps allow get_* methods)
    # move this into Invokable role
    $invokeable_on_set  = [] unless $self->writable;
    $invokeable_on_item = [] unless $self->writable;

    if ($ENV{WEBAPI_DBIC_DEBUG}) {
        warn sprintf "Auto routes for /%s => %s\n",
            $path, $set->result_class;
    }

    my $qr_names = sub {
        my $names_r = join "|", map { quotemeta $_ } @_ or confess "panic";
        return qr/^(?:$names_r)$/x;
    };

    my $resource_default_args = {
        writable => $self->writable,
        http_auth_type => $self->http_auth_type,
        set => $set,
    };

    my @routes;

    push @routes, WebAPI::DBIC::Route->new(
        path => $path,
        resource_class => 'WebAPI::DBIC::Resource::GenericSet',
        resource_args  => $resource_default_args,
    );

    push @routes, WebAPI::DBIC::Route->new( # method call on set
        path => "$path/invoke/:method",
        validations => { method => $qr_names->(@$invokeable_on_set) },
        resource_class => 'WebAPI::DBIC::Resource::GenericSetInvoke',
        resource_args  => $resource_default_args,
    ) if @$invokeable_on_set;


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
            resource_args  => $resource_default_args,
        );

        push @routes, WebAPI::DBIC::Route->new( # method call on item
            path => "$path/$item_path_spec/invoke/:method",
            validations => {
                method => $qr_names->(@$invokeable_on_item),
            },
            resource_class => 'WebAPI::DBIC::Resource::GenericItemInvoke',
            resource_args  => $resource_default_args,
        ) if @$invokeable_on_item;
    }
    else {
        warn sprintf "/%s/:id route skipped because %s has no $id_unique_constraint_name constraint defined\n",
            $path, $set->result_class;
    }

    return @routes;
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


sub to_psgi_app {
    my ($self) = @_;
#local $SIG{__WARN__} = \&Carp::cluck;
    my $router = $self->router_class->new;

    my $route_maker = $self;

    for my $route_spec (@{ $self->routes }) {

        for my $route ($route_maker->routes_for($route_spec)) {

            $router->add_route( $route->as_add_route_args );

        }
    }

    if (0 && not $router->uri_for('')) {
        my $root_route = WebAPI::DBIC::Route->new(
            path => '',
            resource_class => 'WebAPI::DBIC::Resource::GenericRoot',
            resource_args  => {},
        );
        $router->add_route( $root_route );
    }

    return $router->to_psgi_app; # return Plack app
}


1;
__END__
