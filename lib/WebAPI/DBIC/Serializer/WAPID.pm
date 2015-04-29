package WebAPI::DBIC::Serializer::WAPID;

=head1 NAME

WebAPI::DBIC::Serializer::WAPID - Serializer for WebAPI::DBIC's own test media type

=cut

use Moo;

extends 'WebAPI::DBIC::Serializer::Base';

with 'WebAPI::DBIC::Role::JsonEncoder';

sub content_types_accepted {
    return ( [ 'application/vnd.wapid+json' => 'accept_from_json' ] );
}

sub content_types_provided {
    return ( [ 'application/vnd.wapid+json' => 'provide_to_json' ]);
}



sub _create_embedded_resources_from_data {
    my ($self, $data, $result_class) = @_;

    return $self->set->result_source->schema->resultset($result_class)->create($data);
}


sub root_to_json { # informal JSON description, XXX liable to change
    my $self = shift;

    my $request = $self->resource->request;
    my $path = $request->env->{REQUEST_URI}; # "/clients/v1/";
    my %links;
    foreach my $route (@{$self->resource->router->routes})  {
        my @parts;

        for my $c (@{ $route->components }) {
            if ($route->is_component_variable($c)) {
                push @parts, ":".$route->get_component_name($c);
            } else {
                push @parts, "$c";
            }
        }
        next unless @parts;

        my $url = $path . join("/", @parts);
        die "Duplicate path: $url" if $links{$url};
        my $title = join(" ", (split /::/, $route->defaults->{result_class})[-3,-1]);
        $links{$url} = $title;
    }

    return $self->encode_json({
        routes => \%links,
    });
}


1;
