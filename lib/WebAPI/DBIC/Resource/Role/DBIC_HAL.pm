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
        if (not defined $subitem) {
            $data->{_embedded}{$prefetch} = undef; # show an explicit null from a prefetch
        }
        elsif ($subitem->isa('DBIx::Class::ResultSet')) { # one-to-many rel
            my $rel_set_resource = $self->web_machine_resource(set => $subitem, item => undef);
            $data->{_embedded}{$prefetch} = $rel_set_resource->render_set_as_list_of_hal($subitem);
        }
        else {
            $data->{_embedded}{$prefetch} = $self->render_item_as_plain_hash($subitem);
        }
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


sub render_set_as_list_of_hal {
    my ($self, $set, $render_method) = @_;
    $render_method ||= 'render_item_as_hal_hash';

    my $set_data = [ map { $self->$render_method($_) } $set->all ];

    return $set_data;
}


sub render_set_as_hal {
    my ($self, $set) = @_;

    # some params, like distinct, mean we're not returning full resource representations(?)
    # so render the contents of the _embedded set as plain JSON
    my $render_method = ($self->param('distinct'))
        ? 'render_item_as_plain_hash'
        : 'render_item_as_hal_hash';
    my $set_data = $self->render_set_as_list_of_hal($set, $render_method);

    my $data = {};

    my $total_items;
    if (($self->param('with')||'') =~ /count/) { # XXX
        $total_items = $set->pager->total_entries;
        $data->{_meta}{count} = $total_items;
    }

    my ($prefix, $rel) = $self->uri_for(result_class => $set->result_class);
    $data->{_embedded} = {
        $rel => $set_data,
    };
    $data->{_links} = {
        $self->_hal_page_links($set, "$prefix/$rel", scalar @$set_data, $total_items),
    };

    return $data;
}


sub _hal_page_links {
    my ($self, $set, $base, $page_items, $total_items) = @_;

    # XXX we ought to allow at least the self link when not pages
    return () unless $set->is_paged;

    # XXX we break encapsulation here, sadly, because calling
    # $set->pager->current_page triggers a "select count(*)".
    # XXX When we're using a later version of DBIx::Class we can use this:
    # https://metacpan.org/source/RIBASUSHI/DBIx-Class-0.08208/lib/DBIx/Class/ResultSet/Pager.pm
    # and do something like $rs->pager->total_entries(sub { 99999999 })
    my $rows = $set->{attrs}{rows} or confess "panic: rows not set";
    my $page = $set->{attrs}{page} or confess "panic: page not set";

    # XXX this self link this should probably be subtractive, ie include all
    # params by default except any known to cause problems
    my $url = $self->add_params_to_url($base, { distinct=>1, with=>1, me=>1 }, { rows => $rows });
    my $linkurl = $url->as_string;
    $linkurl .= "&page="; # hack to optimize appending page 5 times below

    my @link_kvs;
    push @link_kvs, self  => {
        href => $linkurl.($page),
        title => $set->result_class,
    };
    push @link_kvs, next  => { href => $linkurl.($page+1) }
        if $page_items == $rows;
    push @link_kvs, prev  => { href => $linkurl.($page-1) }
        if $page > 1;
    push @link_kvs, first => { href => $linkurl.1 }
        if $page > 1;
    push @link_kvs, last  => { href => $linkurl.$set->pager->last_page }
        if $total_items and $page != $set->pager->last_page;

    return @link_kvs;
}


1;
