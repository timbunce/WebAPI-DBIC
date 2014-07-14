package WebAPI::DBIC::Util;

# based on webmachine-perl/lib/Web/Machine/Util.pm
#
# ABSTRACT: General Utility module

use strict;
use warnings;

use Carp         qw[ confess ];
use Scalar::Util qw[ blessed ];
use List::Util   qw[ first ];

use HTTP::Headers::ActionPack;

use Sub::Exporter -setup => {
    exports => [qw[
        first
        pair_key
        pair_value
        bind_path
        create_date
        create_header
        inflate_headers
    ]]
};

sub pair_key   { return ( keys   %{ $_[0] } )[0] }
sub pair_value { return ( values %{ $_[0] } )[0] }

{
    my $ACTION_PACK = HTTP::Headers::ActionPack->new;
    sub create_header   { return $ACTION_PACK->create( @_ ) }
    sub create_date     { return $ACTION_PACK->create( 'DateHeader' => shift ) }
    sub inflate_headers { return $ACTION_PACK->inflate( @_ ) }
    sub get_action_pack { return $ACTION_PACK }
}

1;

__END__

=head1 SYNOPSIS

  use WebAPI::DBIC::Util;

=head1 DESCRIPTION

This is just a basic utility module used internally by L<WebAPI::DBIC>.
There is no real user servicable parts in here.

=back

