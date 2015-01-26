package WebAPI::DBIC::Resource::Role::DBICParams;

=head1 NAME

WebAPI::DBIC::Resource::Role::DBICParams - methods for handling url parameters

=cut

use Moo::Role;

use Carp;
use Scalar::Util qw(blessed);
use Try::Tiny;
use Devel::Dwarn;

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
    return qw(page rows sort);
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

        # for parameters with names like foo[x]=3&foo[y]=4
        # we accumulate the value as a hash { x => 3, y => 4 }
        if ($param =~ /^(\w+)\[(\w+)\]$/) {
            die "$param=$v[0] can't follow $param=$queue{$param} parameter\n"
                if $queue{$1} and not ref $queue{$1};
            $queue{$1}{$2} = $v[0];
        }
        else {
            die "$param=$v[0] can't follow $param=$queue{$param} parameter\n"
                if $queue{$param} and ref $queue{$param};
            $param = 'sort' if $param eq 'order'; # XXX back-compat
            $queue{$param} = $v[0];
        }
    }

    # call handlers in desired order, then any remaining ones
    my %done;
    for my $param ($self->get_param_order, keys %queue) {
        next if $done{$param}++;
        my $value = delete $queue{$param};

        my $method = "_handle_${param}_param";
        unless ($self->can($method)) {
            warn "The $param parameter is not supported by the $self resource\n";
            next;
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

    # Prefetchs/join in DBIC accepts either:
    #   prefetch => relname OR
    #   prefetch => [relname1, relname2] OR
    #   prefetch => {relname1 => relname_on_relname1} OR
    #   prefetch => [{relname1 => [{relname_on_relname1 => relname_on_relname_on_relname1}, other_relname_on_relaname1]},relname2] ETC

    # Noramalise all prefetches to most complicated form.
    # eg &prefetch=foo,bar  or  &prefetch.json={...}
    my $prefetch = $self->_resolve_prefetch($value, $self->set->result_source);

    return unless scalar @$prefetch;
    # XXX hack?: perhaps use {embedded}{$key} = sub { ... };
    # see lib/WebAPI/DBIC/Resource/Role/DBIC.pm
    $self->prefetch( $prefetch ); # include self, even if deleted below
    $prefetch = [grep { !defined $_->{self}} @$prefetch];

    my $prefetch_or_join = $self->param('fields') ? 'join' : 'prefetch';
    Dwarn { $prefetch_or_join => $prefetch } if $ENV{WEBAPI_DBIC_DEBUG};
    $self->set( $self->set->search_rs(undef, { $prefetch_or_join => $prefetch }))
        if scalar @$prefetch;

    return;
}

sub _resolve_prefetch {
    my ($self, $prefetch, $result_class) = @_;
    my @errors;

    # Here we recursively resolve each of the prefetches to normalise them all to the most complicated
    # form that can exist. The results will be a ArrayRef of HashRefs that can be passed to DBIC
    # directly.
    # This code is largely taken from the _resolve_join subroutine in DBIx::Class

    return [] unless defined $prefetch and length $prefetch;
    my @return;

    if (ref $prefetch eq 'ARRAY') {
        push @return, map {
            @{$self->_resolve_prefetch($_, $result_class)}
        } @$prefetch;
    } elsif (ref $prefetch eq 'HASH') {
        for my $rel (keys %$prefetch) {
            next if $rel eq 'self';

            if (my @validate_errors = $self->_validate_relationship($result_class, $rel)) {
                push @errors, @validate_errors;
            } else {
                push @return, {
                    $rel => $self->_resolve_prefetch($prefetch->{$rel}, $result_class->related_source($rel))
                };
            }
        }
    } elsif (ref $prefetch) {
        push @errors,
            "No idea how to resolve prefetch reftype ".ref $prefetch;
    } else {
        for my $rel (split ',', $prefetch) {
            my @validate_errors = $self->_validate_relationship($result_class, $rel);
            if ($rel ne 'self' && scalar @validate_errors) {
                push @errors, @validate_errors;
            } else {
                push @return, {
                    $rel => [{}],
                };
            }
        }
    }

    $self->throwable->throw_bad_request(400, errors => \@errors)
        if @errors;

    return \@return;
}

sub _validate_relationship {
    my ($self, $result_class, $rel) = @_;
    my @errors;

    my $rel_info;
    try {
        $rel_info = $result_class->relationship_info($rel);
        local $SIG{__DIE__}; # avoid strack trace from these dies:
        die "no relationship with that name\n"
            if not $rel_info;
        die "relationship is $rel_info->{attrs}{accessor} but only single, filter and multi are supported\n"
            if not $rel_info->{attrs}{accessor} =~ m/^(?:single|filter|multi)$/; # sanity
    }
    catch {
        push @errors, {
            $rel => $_,
            _meta => {
                relationship => $rel_info,
                relationships => [ sort $result_class->relationships ]
            }, # XXX
        };
    };

    return @errors;
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
    }

    $self->set( $self->set->search_rs(undef, { columns => \@columns }) )
        if @columns;

    return;
}


sub _handle_sort_param {
    my ($self, $value) = @_;
    my @order_spec;

    # to support sort[typename]=... we need to be able to make type names
    # to relationship names that map to the type and are included in the query
    # (there might be more than one relationship on 'me' that leads to
    # the same resource type so there's a potential ambiguity)
    if (ref $value) {
        $self->throwable->throw_bad_request(400, errors => [{
            parameter => "per-type sort specifiers are not supported yet",
            _meta => { sort => $value, }, # XXX
        }]);
    }

    if (not defined $value) {
        $value = (join ",", map { "me.$_" } $self->set->result_source->primary_columns);
    }

    for my $clause (split /,/, $value) {

        # we take care to avoid injection risks
        my ($field, $dir);
        if ($clause =~ /^ ([a-z0-9_\.]*)\b (?:\s+(asc|desc))? $/xi) {
            ($field, $dir) = ($1, $2 || 'asc');
        }
        elsif ($clause =~ /^ (-?) ([a-z0-9_\.]*)$/xi) {
            ($field, $dir) = ($2, ($1) ? 'desc' : 'asc');
        }

        unless (defined $field) {
            $self->throwable->throw_bad_request(400, errors => [{
                parameter => "invalid order clause",
                _meta => { order => $clause, }, # XXX
            }]);
        }

        # https://metacpan.org/pod/SQL::Abstract#ORDER-BY-CLAUSES
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
    my $sort = $self->param('sort') || $self->param('order'); # XXX insufficient
    push @errors, "distinct param requires sort (or order) param"
        unless $sort;
    push @errors, "distinct param requires fields param"
        unless $self->param('fields');
    push @errors, "distinct param requires fields and orders parameters to have same value"
        unless $self->param('fields') eq $sort;
    my $errors = join(", ", @errors);
    die "$errors\n" if $errors; # TODO throw?

    $self->set( $self->set->search_rs(undef, { distinct => $value }) );

    return;
}



1;
