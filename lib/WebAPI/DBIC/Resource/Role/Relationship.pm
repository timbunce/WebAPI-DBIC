package WebAPI::DBIC::Resource::Role::Relationship;

use Devel::Dwarn;
use Hash::Util qw(lock_keys);

use Moo::Role;

requires 'uri_for';
requires 'id_column_values_for_item';
requires 'add_params_to_url';


# XXX this should be cached
sub _get_relationship_link_info {
    my ($result_class, $relname) = @_;
    my $rel = $result_class->relationship_info($relname);

    my $link_info = { # what we'll return
        result_class => $rel->{source},
        id_fields => undef,
        id_filter => undef,
    };
    lock_keys(%$link_info);

    my $cond = $rel->{cond};

    # https://metacpan.org/pod/DBIx::Class::Relationship::Base#add_relationship
    if (ref $cond eq 'CODE') {

=for example

        $Data::Dumper::Deparse = 1;
        return {
            "$$args{'foreign_alias'}.artist", {-'ident', "$$args{'self_alias'}.artistid"},
            "$$args{'foreign_alias'}.year", 1984
        },
        $$args{'self_resultobj'} && {
            "$$args{'foreign_alias'}.artist", $$args{'self_resultobj'}->artistid,
            "$$args{'foreign_alias'}.year", 1984
        };

=cut

        my $bail = sub {
            my ($inform) = shift || '';
            unless (our $warn_once->{"$result_class $relname"}++) {
                warn "$result_class relationship $relname has coderef-based condition which is not handled yet $inform\n";
                Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
            }
            return undef;
        };

        return sub {
            my ($self, $code_cond_args) = @_;

            my ($crosstable_cond, $joinfree_cond) = $cond->({
                self_alias        => 'self',    # alias of the invoking resultset ('me' in case of a result object),
                foreign_alias     => 'foreign', # alias of the to-be-joined resultset (often matches relname),
                %$code_cond_args                # eg self_resultsource, foreign_relname, self_rowobj
            });
            #Dwarn [ $crosstable_cond, $joinfree_cond ] unless our $warn_once->{"$result_class $relname dwarn"}++;

            # XXX herein we attempt the insane task of mapping SQL::Abstract conditions
            # into something usable by WebAPI::DBIC - this is a total hack

            for my $crosstable_cond_key (keys %$crosstable_cond) {
                my $cond = $crosstable_cond->{$crosstable_cond_key};

                # first we look for the FK indentity field
                my $ident;
                if (ref $cond eq 'HASH') {
                    if ($cond->{'-ident'}) {
                        # "foreign.artist" => { "-ident" => "self.artistid" },
                        $ident = $cond->{'-ident'}
                    }
                    elsif (ref $cond->{'='} eq 'HASH' && $cond->{'='}{'-ident'}) {
                        # "foreign.artist" => { "=" => { "-ident" => "self.artistid" } }
                        $ident = $cond->{'='}{'-ident'};
                    }
                    elsif (ref $cond->{'='} eq 'SCALAR') {
                        # "foreign.artist" => { "=" => \"self.artistid" },
                        $ident = ${ $cond->{'='} };
                    }
                }

                if ($ident) {
                    $ident =~ s/^self\.// or die "panic";
                    $link_info->{id_fields} = [ $ident ];
                }
                else {
                    # other kinds of conditions which we'll translate into me.field=foo url params
                    return $bail->('- unknown crosstable_cond_key');
                }
            }

            if ($joinfree_cond) {
                # The join-free condition returned for relationship '$rel_name' must be a hash
                # reference with all keys being valid columns on the related result source
                return $bail->('- has join-free condition');
            }

            return $link_info;
        };
    }

    if (ref $cond ne 'HASH') {
        # we'll may end up silencing this warning till we can offer better support
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname cond value $cond not handled yet\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    if (keys %$cond > 1) {
        # if we loosen this constraint we might need to recheck it for some cases below
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since it has multiple conditions\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    # TODO support and test more kinds of relationships
    # TODO refactor

    if ($rel->{attrs}{accessor} eq 'multi') { # a 1-to-many relationship

        # XXX are there any cases we're not dealing with here?
        # such as multi-colum FKs

        Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};

        my $foreign_key = (keys %$cond)[0];
        $foreign_key =~ s/^foreign\.//
            or warn "Odd, no 'foreign.' prefix on $foreign_key ($result_class, $relname)";

        # express that we want to filter the many to match the key(s) of the 1
        # here we list the names of the fields in the foreign table that correspond
        # to the names of the id columns in the result_class table
        $link_info->{id_filter} = [ $foreign_key ];
        return $link_info;
    }

    # accessor is the inflation type (single/filter/multi)
    if ($rel->{attrs}{accessor} !~ /^(?: single | filter )$/x) {
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since we only support 'single' accessors (not $rel->{attrs}{accessor}) at the moment\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    my $fieldname = (values %$cond)[0]; # first and only value
    $fieldname =~ s/^self\.// if $fieldname;

    if (not $fieldname) {
        unless (our $warn_once->{"$result_class $relname"}++) {
            warn "$result_class relationship $relname ignored since we can't determine a fieldname (@{[ %$cond ]})\n";
            Dwarn $rel if $ENV{WEBAPI_DBIC_DEBUG};
        }
        return undef;
    }

    $link_info->{id_fields} = [ $fieldname ];
    return $link_info;
}


=head2 get_url_for_item_relationship

    $url = $self->get_url_for_item_relationship($item, $relname);

Given a specific item and relationship name return a url for the related
records, if possible else return undef.

=cut

sub get_url_for_item_relationship {
    my ($self, $item, $relname) = @_;

    my $result_class = $item->result_class;

    #Dwarn
    my $rel_link_info = _get_relationship_link_info($result_class, $relname)
        or return undef;

    if (ref $rel_link_info eq 'CODE') {
        $rel_link_info = $rel_link_info->($self, {
            self_resultsource => $item->result_source,
            self_rowobj       => $item,
            foreign_relname   => $relname, # XXX ?
        })
            or return undef;
    }

    my @uri_for_args;
    if ($rel_link_info->{id_fields}) { # link to an item (1-1)
        my @id_kvs = map { $item->get_column($_) } @{ $rel_link_info->{id_fields} };
        return undef if grep { not defined } @id_kvs; # no link because a key value is null
        push @uri_for_args, map { $_ => shift @id_kvs } 1..@id_kvs;
    }

    my $dst_class = $rel_link_info->{result_class} or die "panic";
    push @uri_for_args, result_class => $dst_class;

    my $linkurl = $self->uri_for( @uri_for_args );

    if (not $linkurl) {
        warn "Result source $dst_class has no resource uri in this app so relations (like $result_class $relname) won't have _links for it.\n"
            unless our $warn_once->{"$result_class $relname $dst_class"}++;
        return undef;
    }

    my %params;
    if (my $id_filter = $rel_link_info->{id_filter}) {
        my @id_vals = $self->id_column_values_for_item($item);
        die "panic" if @id_vals != @$id_filter;
        for my $id_field (@$id_filter) {
            $params{ "me.".$id_field } = shift @id_vals;
        }
    }

    my $href = $self->add_params_to_url(
        $linkurl,
        {},
        \%params,
    );

    return $href;
}

1;
