package WebAPI::DBIC::Resource::Role::DBICParams;

use Moo::Role;

use Carp;
use Scalar::Util qw(blessed);


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
        my @v = $self->param($param);
        # XXX we don't handle multiple params which appear more than once
        die "multiple $param parameters supplied" if @v > 1;

        (my $basename = $param) =~ s/\..*//; # 'me.id' => 'me'

        push @{ $queue{$basename} }, [ $param, $v[0] ];

    };

    # call handlers in desired order, then any remaining ones
    my %done;
    for my $basename ($self->get_param_order, keys %queue) {
        next if $done{$basename}++;

        my $specs = $queue{$basename} || [ [ $basename, undef ] ];
        for my $spec (@$specs) {
            my ($param, $value) = @$spec;

            my $method = "_handle_${basename}_param";
            die "The $param parameter is not supported by the $self resource"
                unless $self->can($method);
            $self->$method($value, $param);
        }
    }

    return 0;
}


sub _handle_rows_param {
    my ($self, $value) = @_;
    $value = 30 unless defined $value;
    $self->set( $self->set->search_rs(undef, { rows => $value }) );
}


sub _handle_page_param {
    my ($self, $value) = @_;
    $value = 1 unless defined $value;
    $self->set( $self->set->search_rs(undef, { page => $value }) );
}


sub _handle_with_param { }


sub _handle_rollback_param { }


sub _handle_me_param {
    my ($self, $value, $param) = @_;
    # we use me.relation.field=... to refer to relations via this param
    # so the param can be recognized by the leading 'me.'
    # but we strip off the leading 'me.' if there's a me.foo.bar
    $param =~ s/^me\.// if $param =~ m/^me\.\w+\.\w+/;
    $self->set( $self->set->search_rs({ $param => $value }) );
}


sub _handle_prefetch_param {
    my ($self, $value) = @_;

    my %prefetch = map { $_ => {} } split(',', $value||"");
    return unless %prefetch;

    my $result_class = $self->set->result_class;
    for my $prefetch (keys %prefetch) {

        next if $prefetch eq 'self'; # used in POST/PUT handling

        my $rel = $result_class->relationship_info($prefetch);

        # limit to simple single relationships, e.g., belongs_to
        $self->throwable->throw_bad_request(400, errors => [{
                    $prefetch => "not a valid relationship",
                    _meta => {
                        relationship => $rel,
                        relationships => [ $result_class->relationships ]
                    }, # XXX
                }])
            unless $rel
                and $rel->{attrs}{accessor} eq 'single'       # sanity
                and $rel->{attrs}{is_foreign_key_constraint}; # safety/speed
    }

    # XXX hack?: perhaps use {embedded}{$key} = sub { ... };
    # see lib/WebAPI/DBIC/Resource/Role/DBIC.pm
    $self->prefetch({ %prefetch });

    delete $prefetch{self};
    $self->set( $self->set->search_rs(undef, { prefetch => [ keys %prefetch ] }))
        if %prefetch;
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
        my ($field) = ($clause =~ /^([a-z0-9_\.]*)$/);
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
}


sub _handle_order_param {
    my ($self, $value) = @_;
    my @order_spec;

    if (not defined $value) {
        $value = (join ",", map { "me.$_" } $self->set->result_source->primary_columns);
    }

    for my $clause (split /\s*,\s*/, $value) {
        # we take care to avoid injection risks
        my ($field, $dir) = ($clause =~ /^([a-z0-9_\.]*)\b(?:\s+(asc|desc))?\s*$/i);
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
    die join(", ", @errors) if @errors; # XXX throw

    $self->set( $self->set->search_rs(undef, { distinct => $value }) );
}



1;
