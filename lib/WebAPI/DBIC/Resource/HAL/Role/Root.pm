package WebAPI::DBIC::Resource::HAL::Role::Root;

=head1 NAME

WebAPI::DBIC::Resource::HAL::Role::Root - provide a description of the API for HAL browser

=head1 DESCRIPTION

=cut

use Moo::Role;

use Types::Serialiser;

requires '_build_content_types_provided';
requires 'encode_json';


around '_build_content_types_provided' => sub {
    my $orig = shift;
    my $self = shift;
    my $types = $self->$orig();
    unshift @$types, { 'application/hal+json' => 'to_json_as_hal' };
    return $types;
};


sub to_json_as_hal { return $_[0]->encode_json($_[0]->render_api_as_hal()) }


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
                $attr{templated} = Types::Serialiser::true;
            } else {
                push @parts, "$c";
            }
        }
        next unless @parts;

        my $url = $path . join("", @parts);
        $links{join("", @parts)} = {
            href => $url,
            title => $route->defaults->{_title}||"",
            %attr
        };
    }

    return { _links => \%links, };
}


1;
