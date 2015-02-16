package TestWebApp;

use Moo;
extends 'WebAPI::DBIC::WebApp';

require WebAPI::DBIC::RouteMaker;


sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = { (@args == 1) ? %{$args[0]} : @args };
    
    $args->{route_maker} ||= WebAPI::DBIC::RouteMaker->new();

    my $resource_default_args = $args->{route_maker}->resource_default_args;
    $resource_default_args->{writable}       = 1;
    $resource_default_args->{http_auth_type} = 'disabled';
    
    return $args;
};




1;
