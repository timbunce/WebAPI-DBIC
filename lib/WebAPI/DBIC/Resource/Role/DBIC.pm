package WebAPI::DBIC::Resource::Role::DBIC;

use Moo::Role;

# XXX probably shouldn't be a role, just functions, or perhaps a separate rendering object

sub base_uri { # XXX hack - use the router
    my ($self) = @_;
    use Devel::Dwarn;
    my $base = $self->request->env->{PATH_INFO};
    $base =~ s:^(/\w+).*:$1:;
    return $base;
}

# default render for DBIx::Class item
# https://metacpan.org/module/DBIx::Class::Manual::ResultClass
# https://metacpan.org/module/DBIx::Class::InflateColumn
sub render_item_as_plain {
    my ($self, $item) = @_;
    my $data = { $item->get_columns }; # XXX ?
    # FKs
    # DateTimes
    return $data;
}

sub render_item_as_hal {
    my ($self, $item) = @_;
    my $base = $self->base_uri;
    my $data = $self->render_item_as_plain($item);
    $data->{_links} = {
        self => { href => $base."/".$item->id }
    };
    return $data;
}


sub render_set_as_plain {
    my ($self, $set) = @_;
    my $set_data = [ map { $self->render_item_as_plain($_) } $set->all ];
    return $set_data;
}


sub _hal_page_link {
    my ($set, $base, $dir) = @_;
    return () unless $set->is_paged;
    my $method = ($dir eq 'prev') ? "previous_page" : "next_page";
    my $page = $set->pager->$method();
    return () if not defined $page;
    return ($dir => { href => "$base?page=$page" });
}

sub render_set_as_hal {
    my ($self, $set) = @_;
    my $data = {
       _embedded => {
          person_types => [ map { $self->render_item_as_hal($_) } $set->all ],
      }
    };
    my $base = $self->base_uri;
    $data->{_links} = {
        self => { href => "$base" },
        _hal_page_link($set, $base, "prev"),
        _hal_page_link($set, $base, "next"),
    };
    return $data;
}


sub finish_request {
    my ($self, $metadata) = @_;

    my $exception = $metadata->{'exception'};
    return unless $exception;

    warn sprintf "finish_request %.50s", $exception;

    my $error_data;
    # ... DBD::Pg::st execute failed: ERROR:  column "nonesuch" does not exist
    if ($exception =~ m/DBD::Pg.*? failed:.*? column "(.*?)" (.*)/) {
        $error_data = {
            status => 400,
            foo => "$1: $2",
        };
    }

    if ($error_data) {
        $error_data->{exception} = "$exception" # stringify
            unless $ENV{TL_ENVIRONMENT} eq 'production';
        $error_data->{status} ||= 500;
        # create response
        my $json = JSON->new->ascii->pretty;
        my $response = $self->response;
        $response->status($error_data->{status});
        my $body = $json->encode($error_data);
        $response->body($body);
        $response->content_length(length $body);
        $response->content_type('application/json');
    }
}


1;
