package WebAPI::DBIC::Resource::Role::SetWritable;

=head1 NAME

WebAPI::DBIC::Resource::Role::SetWritable - methods handling requests to update set resources

=head1 DESCRIPTION

Handles POST requests for resources representing set resources, e.g. to insert
rows into a database table.

Supports the C<application/json> content type.

=cut

use Devel::Dwarn;
use Carp qw(confess);

use Moo::Role;


requires 'serializer';
requires 'decode_json';
requires 'set';
requires 'prefetch';
requires 'writable';
requires 'path_for_item';
requires 'allowed_methods';


has item => ( # for POST to create
    is => 'rw',
);

has content_types_accepted => (
    is => 'lazy',
);

sub _build_content_types_accepted {
    return [ {
        'application/vnd.wapid+json' => sub {
            my $self = shift;
            require WebAPI::DBIC::Serializer::WAPID;
            $self->serializer(WebAPI::DBIC::Serializer::WAPID->new(resource => $self));
            return $self->from_plain_json;
        },
    } ];
}

around 'allowed_methods' => sub {
    my $orig = shift;
    my $self = shift;
    my $methods = $self->$orig();
    push @$methods, 'POST' if $self->writable;
    return $methods;
};


sub post_is_create { return 1 }

sub create_path_after_handler { return 1 }


sub from_plain_json {
    my $self = shift;
    my $item = $self->create_resource( $self->decode_json($self->request->content) );
    return $self->item($item);
}


sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}


sub create_resource {
    my ($self, $data) = @_;

    my $item = $self->set->create($data);

    # resync with what's (now) in the db to pick up defaulted fields etc
    $item->discard_changes();

    # called here because create_path() is too late for Web::Machine
    $self->render_item_into_body(item => $item)
        if grep {defined $_->{self}} @{$self->prefetch||[]};

    return $item;
}


1;
