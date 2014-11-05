package WebAPI::DBIC::Resource::Role::DBICParams;

=head1 NAME

WebAPI::DBIC::Resource::Role::DBICParams - methods for handling url parameters

=cut

use Carp;
use Scalar::Util qw(blessed);
use Try::Tiny;

use Moo::Role;


requires 'set';
requires 'throwable';
requires 'prefetch';

# TODO the params supported by a resource should be determined by the roles
# consumed by that resource, plus any extra params it wants to declare support for.
# So this should be reworked to enable that.


# we use malformed_request() call from Web::Machine to trigger parameter processing
sub malformed_request {
    my $self = shift;

    $self->handle_request_params;

    return 0;
}


# used to a) define order that params are handled,
# and b) to force calling of a handler even if param is missing
sub get_param_order {
    return qw(page rows order);
}


# call _handle_${basename}_param methods for each parameter
# where basename is the name with any .suffix removed ('me.id' => 'me')
sub handle_request_params {
    my $self = shift;

    my %queue;
    for my $param ($self->param) {
        next if $param eq ""; # ignore empty parameters

        my @v = $self->param($param);
        # XXX we don't handle multiple params which appear more than once
        die "Multiple $param parameters are not supported\n" if @v > 1;

        # parameters with names containing a '.' are assumed to be search criteria
        # this covers both 'me.field=foo' and 'relname.field=bar'
        if ($param =~ /^\w+\.\w+/) {
            $param =~ s/^me\.(\w+\.\w+)/$1/; # handle deprecated 'me.relname.fieldname' form
            $queue{search_criteria}->{$param} = $v[0];
            next;
        }
        die "Explicit search_criteria param not allowed"
            if $param eq 'search_criteria';

        $queue{$param} = $v[0];
    }

    # call handlers in desired order, then any remaining ones
    my %done;
    for my $param ($self->get_param_order, keys %queue) {
        next if $done{$param}++;
        my $value = delete $queue{$param};

        my $method = "_handle_${param}_param";
        unless ($self->can($method)) {
            die "The $param parameter is not supported by the $self resource\n";
        }
        $self->$method($value, $param);
    }

    return 0;
}


## no critic (ProhibitUnusedPrivateSubroutines)

sub _handle_rows_param {
    my ($self, $value) = @_;
    $value = 30 unless defined $value;
    $self->set( $self->set->search_rs(undef, { rows => $value }) );
    return;
}


sub _handle_page_param {
    my ($self, $value) = @_;
    $value = 1 unless defined $value;
    $self->set( $self->set->search_rs(undef, { page => $value }) );
    return;
}


sub _handle_with_param { }


sub _handle_rollback_param { }


sub _handle_search_criteria_param {
    my ($self, $value) = @_;
    $self->set( $self->set->search_rs($value) );
    return;
}


sub _handle_prefetch_param {
    my ($self, $value) = @_;

    my %prefetch = (ref $value)
        ? %$value # eg &prefetch.json={...}
        : map { $_ => {} } split(',', $value||"");
    return unless %prefetch;

    my $result_class = $self->set->result_class;
    my @errors;
    for my $prefetch (keys %prefetch) {

        next if $prefetch eq 'self'; # used in POST/PUT handling

        my $rel;
        try {
            $rel = $result_class->relationship_info($prefetch);
            local $SIG{__DIE__}; # avoid strack trace from these dies:
            die "no relationship with that name"
                if not $rel;
            die "relationship is $rel->{attrs}{accessor} but only single and filter are supported\n"
                if not $rel->{attrs}{accessor} =~ m/^(?:single|filter)$/ # sanity
        }
        catch {
            push @errors, {
                $prefetch => $_,
                _meta => {
                    relationship => $rel,
                    relationships => [ $result_class->relationships ]
                }, # XXX
            };
        }
    }

    $self->throwable->throw_bad_request(400, errors => \@errors)
        if @errors;

    # XXX hack?: perhaps use {embedded}{$key} = sub { ... };
    # see lib/WebAPI/DBIC/Resource/Role/DBIC.pm
    $self->prefetch({ %prefetch });

    delete $prefetch{self};
    $self->set( $self->set->search_rs(undef, { prefetch => [ keys %prefetch ] }))
        if %prefetch;

    return;
}


sub _handle_fields_param {
    my ($self, $value) = @_;
    my @columns;

    if (ref $value eq 'ARRAY') {
        @columns = @$value;
    }
    else {
        @columns = split /\s*,\s*/, $value;
    }

    for my $clause (@columns) {
        # we take care to avoid injection risks
        my ($field) = ($clause =~ /^ ([a-z0-9_\.]*) $/x);
        $self->throwable->throw_bad_request(400, errors => [{
            parameter => "invalid fields clause",
            _meta => { fields => $field, }, # XXX
        }]) if not defined $field;
        # sadly columns=>[...] doesn't work to limit the fields of prefetch relations
        # so we disallow that for now. It's possible we could achieve the same effect
        # using explicit join's for non-has-many rels, or perhaps using
        # as_subselect_rs
        $self->throwable->throw_bad_request(400, errors => [{
            parameter => "invalid fields clause - can't refer to prefetch relations at the moment",
            _meta => { fields => $field, }, # XXX
        }]) if $field =~ m/\./;
    }

    $self->set( $self->set->search_rs(undef, { columns => \@columns }) )
        if @columns;

    return;
}


sub _handle_order_param {
    my ($self, $value) = @_;
    my @order_spec;

    if (not defined $value) {
        $value = (join ",", map { "me.$_" } $self->set->result_source->primary_columns);
    }

    for my $clause (split /\s*,\s*/x, $value) {
        # we take care to avoid injection risks
        my ($field, $dir) = ($clause =~ /^ ([a-z0-9_\.]*)\b (?:\s+(asc|desc))? \s* $/xi);
        unless (defined $field) {
            $self->throwable->throw_bad_request(400, errors => [{
                parameter => "invalid order clause",
                _meta => { order => $clause, }, # XXX
            }]);
        }
        $dir ||= 'asc';
        push @order_spec, { "-$dir" => $field };
    }

    $self->set( $self->set->search_rs(undef, { order_by => \@order_spec }) )
        if @order_spec;

    return;
}


sub _handle_distinct_param {
    my ($self, $value) = @_;
    my @errors;

    # these restrictions avoid edge cases we don't want to deal with yet
    push @errors, "distinct param requires order param"
        unless $self->param('order');
    push @errors, "distinct param requires fields param"
        unless $self->param('fields');
    push @errors, "distinct param requires fields and orders parameters to have same value"
        unless $self->param('fields') eq $self->param('order');
    my $errors = join(", ", @errors);
    die "$errors\n" if $errors; # TODO throw?

    $self->set( $self->set->search_rs(undef, { distinct => $value }) );

    return;
}



1;
