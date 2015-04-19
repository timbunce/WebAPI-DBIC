package WebAPI::DBIC::Resource::HAL::Role::Root;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::Root - provide a description of the API for HAL browser

=head1 DESCRIPTION

=cut

use Moo::Role;

use JSON::MaybeXS qw(JSON);

use WebAPI::DBIC::Serializer::HAL;

requires '_build_content_types_provided';
requires 'encode_json';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, {
        'application/hal+json' => sub {
            my $self = shift;
            #$self->serializer(WebAPI::DBIC::Serializer::HAL->new(resource => $self));
            return $self->to_json_as_hal;
        },
    };
    return $types;
};


sub to_json_as_hal {
    my $self = shift;

    return $self->encode_json($self->render_api_as_hal())
}


sub render_api_as_hal {
    my $self = shift;

    my $request = $self->request;
    my $router = $self->router;
    my $path = $request->env->{REQUEST_URI}; # "/clients/v1/";

    # we get here when the HAL Browser requests the root JSON
    my %links = (self => { href => $path } );
    foreach my $route (@{$router->routes})  {
        my @parts;
        my %attr;

        for my $c (@{ $route->components }) {
            if ($route->is_component_variable($c)) {
                my $name = $route->get_component_name($c);
                push @parts, "{/$name}";
                $attr{templated} = JSON->true;
            } else {
                push @parts, "$c";
            }
        }
        next unless @parts;

        my $title;
        if (exists $route->defaults->{result_class}) {
            $title = join(" ", (split /::/, $route->defaults->{result_class})[-3,-1]);
        } else {
            ($title) = split( /\?/, $route->path);
        }

        my $url = $path . join("", @parts);
        $links{join("", @parts)} = {
            href => $url,
            title => $title,
            %attr
        };
    }

    return { _links => \%links, };
}


1;
