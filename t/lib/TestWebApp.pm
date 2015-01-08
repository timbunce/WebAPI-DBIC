package TestWebApp;

use Moo;
extends 'WebAPI::DBIC::WebApp';


sub BUILDARGS {
    my ( $class, @args ) = @_;
    my $args = { (@args == 1) ? %{$args[0]} : @args };
    
    $args->{resource_default_args}->{writable} = 1;
    $args->{resource_default_args}->{http_auth_type} = 'disabled';
    
    return $args;
};




1;
