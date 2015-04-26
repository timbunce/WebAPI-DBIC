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
    my $self = shift;
    my @serializer_classes = qw(
        WebAPI::DBIC::Serializer::WAPID
        WebAPI::DBIC::Serializer::ActiveModel
        WebAPI::DBIC::Serializer::HAL
        WebAPI::DBIC::Serializer::JSONAPI
    );
    my @handlers;
    for my $serializer_class (@serializer_classes) {
        use Module::Runtime qw(require_module); # XXX
        require_module($serializer_class);
        for my $content_type_pair ($serializer_class->content_types_accepted) {
            my ($content_type, $method) = @$content_type_pair;
            my $handler_sub = sub {
                my $self = shift;
                my $serializer = $serializer_class->new(resource => $self);
                $self->serializer($serializer);
                return $serializer->$method($self->request->content);
            };
            push @handlers, { $content_type => $handler_sub };
        }
    }
    return \@handlers;
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


sub create_path {
    my $self = shift;
    return $self->path_for_item($self->item);
}


1;
