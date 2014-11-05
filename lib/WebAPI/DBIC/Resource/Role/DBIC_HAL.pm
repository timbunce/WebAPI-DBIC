package WebAPI::DBIC::Resource::Role::DBIC_HAL;

=head1 NAME

WebAPI::DBIC::Resource::Role::DBIC_HAL - a role with core HAL methods for DBIx::Class resources

=cut

use Carp qw(croak confess);
use Devel::Dwarn;
use JSON::MaybeXS qw(JSON);

use Moo::Role;


requires 'get_url_for_item_relationship';
requires 'render_item_as_plain_hash';
requires 'path_for_item';
requires 'add_params_to_url';
requires 'prefetch';


sub render_item_as_hal_hash {
    my ($self, $item) = @_;

    my $data = $self->render_item_as_plain_hash($item);

    my $itemurl = $self->path_for_item($item);
    $data->{_links}{self} = {
        href => $self->add_params_to_url($itemurl, {}, {})->as_string,
    };

    while (my ($prefetch, $info) = each %{ $self->prefetch || {} }) {
        next if $prefetch eq 'self';
        my $subitem = $item->$prefetch();
        # XXX perhaps render_item_as_hal_hash but requires cloned WM, eg without prefetch
        # If we ever do render_item_as_hal_hash then we need to ensure that "a link
        # inside an embedded resource implicitly relates to that embedded
        # resource and not the parent."
        # See http://blog.stateless.co/post/13296666138/json-linking-with-hal
        $data->{_embedded}{$prefetch} = (defined $subitem)
            ? $self->render_item_as_plain_hash($subitem)
            : undef; # show an explicit null from a prefetch
    }

    my $curie = (0) ? "r" : ""; # XXX we don't use CURIE syntax yet

    # add links for relationships
    for my $relname ($item->result_class->relationships) {

        my $url = $self->get_url_for_item_relationship($item, $relname)
            or next;

        $data->{_links}{ ($curie?"$curie:":"") . $relname} = { href => $url->as_string };
    }
    if ($curie) {
       $data->{_links}{curies} = [{
         name => $curie,
         href => "http://docs.acme.com/relations/{rel}", # XXX
         templated => JSON->true,
       }];
   }

    return $data;
}


1;
