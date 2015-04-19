package WebAPI::DBIC::Serializer::Base;

=head1 NAME

WebAPI::DBIC::Serializer::Base - what will I become?

=cut

use Moo;

use Carp;


has resource => (
    is => 'ro',
    required => 1,
    weak_ref => 1,
    # XXX these are here for now to ease migration to use of a serializer object
    # they also serve to identify areas that probably need refactoring/abstracting
    handles => [qw(
        set

        type_namer
        get_url_template_for_set_relationship
        get_url_for_item_relationship
        uri_for
        prefetch
        param
        add_params_to_url
        path_for_item
        web_machine_resource
    )],
);

sub BUILD {
    warn "Using ".ref(shift) if $ENV{WEBAPI_DBIC_DEBUG};
}


sub set_to_json   {
    my ($self, $set) = @_;
    return $self->encode_json($self->render_set_as_plain($set));
}


sub item_to_json {
    my ($self, $item) = @_;
    return $self->resource->encode_json($self->render_item_as_plain_hash($item))
}


# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain_hash {
    my ($self, $item) = @_;
    Carp::confess "undef item" unless defined $item;
    my $data = { $item->get_columns }; # XXX ?
    # XXX inflation, DateTimes, etc.
    return $data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain_hash($_) } $set->all ];
    return $set_data;
}


sub create_should_prefetch_self {
    my $self = shift;
    return scalar grep {defined $_->{self}} @{$self->prefetch||[]};
}


sub create_resources_from_data {
    my ($self, $data) = @_;
    my $item;

    my $schema = $self->set->result_source->schema;

    # XXX perhaps the transaction wrapper belongs higher in the stack
    # but it has to be below the auth layer which switches schemas
    $schema->txn_do(sub {

        $item = $self->_create_embedded_resources_from_data($data, $self->set->result_class);

        # resync with what's (now) in the db to pick up defaulted fields etc
        $item->discard_changes();

        # called here because create_path() is too late for Web::Machine
        # and we need it to happen inside the transaction for rollback=1 to work
        $self->resource->render_item_into_body(
                set => $self->set,
                item => $item,
                type_namer => $self->type_namer,
                prefetch => $self->prefetch,
            )
            if $self->create_should_prefetch_self;

        $schema->txn_rollback if $self->param('rollback'); # XXX

    });

    return $item;
}


# recurse into a prefetch-like structure invoking a callback
# XXX still a work in progress, only used by ActiveModule so far
sub traverse_prefetch {
    my $self = shift;
    my $set = shift;
    my $parent_rel = shift;
    my $prefetch = shift;
    my $callback = shift;

    return unless $prefetch;

    if (not ref($prefetch)) { # leaf node
        $callback->($self, $set, $parent_rel, $prefetch);
        return;
    }

    if (ref($prefetch) eq 'HASH') {
        while (my ($prefetch_key, $prefetch_value) = each(%$prefetch)) {
            warn "traverse_prefetch [@$parent_rel] $prefetch\{$prefetch_key}\n"
                if $ENV{WEBAPI_DBIC_DEBUG};
            next if $prefetch_key eq 'self';

            $self->traverse_prefetch($set, $parent_rel,   $prefetch_key, $callback);

            # XXX traverse_prefetch first arg is a set but this passes a class:
            my $result_subclass = $set->result_class->relationship_info($prefetch_key)->{class};

            $self->traverse_prefetch($result_subclass, [ @$parent_rel, $prefetch_key ], $prefetch_value, $callback);
        }
    }
    elsif (ref($prefetch) eq 'ARRAY') {
        for my $sub_prefetch (@$prefetch) {
            $self->traverse_prefetch($set, $parent_rel, $sub_prefetch, $callback);
        }
    }
    else {
        confess "Unsupported ref(prefetch): " . ref($prefetch);
    }

    return;
}

1;
