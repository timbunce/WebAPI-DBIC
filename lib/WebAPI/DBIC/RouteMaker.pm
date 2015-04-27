package WebAPI::DBIC::RouteMaker;

=head1 NAME

WebAPI::DBIC::RouteMaker - Make routes for resultsets

=cut

use Moo;

use Module::Runtime qw(use_module);
use Sub::Util qw(subname);
use Scalar::Util qw(blessed);
use Carp qw(croak confess);
use Safe::Isa;
use Devel::Dwarn;

use namespace::clean -except => [qw(meta)];
use MooX::StrictConstructor;

use WebAPI::DBIC::Route;

has resource_class_for_item        => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItem');
has resource_class_for_item_invoke => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericItemInvoke');
has resource_class_for_set         => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericSet');
has resource_class_for_set_invoke  => (is => 'ro', default => 'WebAPI::DBIC::Resource::GenericSetInvoke');
has resource_default_args          => (is => 'ro', default => sub { {} });

sub _mk_content_type_handler {
    my ($serializer_class, $pair) = @_;

    my ($content_type, $method) = @$pair;
    my $handler_sub = sub {
        my $self = shift;
        warn sprintf "%s %s content-type %s handled by %s %s\n",
            $self->request->method, $self->request->path, $content_type, $serializer_class, $method
            if $ENV{WEBAPI_DBIC_DEBUG};
        $self->serializer( $serializer_class->new(resource => $self) );
        return $self->$method();
    };
    return { $content_type => $handler_sub };
}

sub _mk_content_type_handlers {
    my ($serializer_classes, $content_types_method) = @_;

    my @handlers;
    for my $serializer_class (@$serializer_classes) {

        use Module::Runtime qw(require_module); # XXX
        require_module($serializer_class);

        for my $content_type_pair ($serializer_class->$content_types_method) {
            push @handlers, _mk_content_type_handler($serializer_class, $content_type_pair);
        }
    }
    return \@handlers;
}

has serializer_classes => (
    is => 'ro',
    default => sub { [ qw(
        WebAPI::DBIC::Serializer::WAPID
        WebAPI::DBIC::Serializer::ActiveModel
        WebAPI::DBIC::Serializer::HAL
        WebAPI::DBIC::Serializer::JSONAPI
    ) ] },
);

has content_types_accepted => (
    is => 'lazy',
);

sub _build_content_types_accepted {
    my $self = shift;
    return _mk_content_type_handlers($self->serializer_classes, 'content_types_accepted');
}

has content_types_provided => (
    is => 'lazy',
);

sub _build_content_types_provided {
    my $self = shift;
    return _mk_content_type_handlers($self->serializer_classes, 'content_types_provided');
}


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

    my @routes;

    push @routes, WebAPI::DBIC::Route->new( # item
        path => "$path/$item_path_spec",
        resource_class => $self->resource_class_for_item,
        resource_args  => {
            %{ $self->resource_default_args },
            content_types_accepted => $self->content_types_accepted,
            content_types_provided => $self->content_types_provided,
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
        resource_class => $self->resource_class_for_item_invoke,
        resource_args  => {
            %{ $self->resource_default_args },
            content_types_accepted => $self->content_types_accepted,
            content_types_provided => $self->content_types_provided,
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

    my @routes;

    push @routes, WebAPI::DBIC::Route->new(
        path => $path,
        resource_class => $self->resource_class_for_set,
        resource_args  => {
            %{ $self->resource_default_args },
            content_types_accepted => $self->content_types_accepted,
            content_types_provided => $self->content_types_provided,
            set => $set,
            type_namer => $self->type_namer,
        },
    );

    # XXX temporary hack just for testing
    push @$methods, 'count'
        if $set->result_class eq 'TestSchema::Result::Artist';

    push @routes, WebAPI::DBIC::Route->new( # method call on set
        path => "$path/invoke/:method",
        validations => { method => _qr_names(@$methods) },
        resource_class => $self->resource_class_for_set_invoke,
        resource_args  => {
            %{ $self->resource_default_args },
            content_types_accepted => $self->content_types_accepted,
            content_types_provided => $self->content_types_provided,
            set => $set,
            type_namer => $self->type_namer,
        },
    ) if $methods && @$methods;

    return @routes;
}

sub make_root_route {
    my $self = shift;
    my $root_route = WebAPI::DBIC::Route->new(
        path => '',
        resource_class => 'WebAPI::DBIC::Resource::GenericRoot',
        resource_args  => {
            %{ $self->resource_default_args },
            content_types_accepted => $self->content_types_accepted,
            content_types_provided => $self->content_types_provided,
            type_namer => $self->type_namer,
        },
    );
    return $root_route;
}

sub make_routes_for {
    my ($self, $route_spec) = @_;

    # route_spec:
    #   $schema->source('People')
    #   { set => $schema->source('People'), path => undef }
    #   { set => $schema->resultset('People')->search({ tall=>1 }), path => 'tall_people' }
    #   WebAPI::DBIC::Route->new(...) # gets used directly

    return $route_spec if $route_spec->$_isa('WebAPI::DBIC::Route');

    my %opts;

    if (ref $route_spec eq 'HASH') {
        # invokeable_methods_on_item => undef,
        # invokeable_methods_on_set  => undef,
        %opts = %$route_spec;
        $route_spec = delete $opts{set};
    }

    if ($route_spec->$_isa('DBIx::Class::ResultSource')) {
        $route_spec = $route_spec->resultset;
        # $opts{is_canonical_source} = 1;
    } elsif ($route_spec->$_isa('DBIx::Class::ResultSet')) {
        # $route_spec is already a resultset, but is a non-canonical source
        # $opts{is_canonical_source} //= 0;
    } else {
        croak "Don't know how to convert '$route_spec' into to a DBIx::Class::ResultSet or WebAPI::DBIC::Resource::Role::Route";
    }

    my $path = delete($opts{path}) || $self->type_namer->type_name_for_resultset($route_spec);

    return $self->make_routes_for_resultset($path, $route_spec, %opts);
}

1;
