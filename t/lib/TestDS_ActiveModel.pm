package TestDS_ActiveModel;

use Test::Most;
use TestDS;
use Devel::Dwarn;
use Carp;

use parent 'Exporter';


our @EXPORT = qw(
    dsreq_activemodel
    has_activemodel_embedded
    has_activemodel_embedded_list
);


sub dsreq_activemodel {
    my ($method, $uri, $headers, $data) = @_;
    my @headers = (
        'Content-Type' => 'application/json',
        'Accept' => 'application/json',
        @{$headers || []}
    );
    return dsreq($method, $uri, \@headers, $data);
}


sub has_activemodel_embedded {
    my ($data, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    die "these HAL tests need to be rewritten to match ActiveModel";
    # XXX these HAL tests need to be rewritten to match ActiveModel
    #is ref $data->{_embedded}, 'HASH', "_embedded isn't hash" or diag $data;
    #my $e = $data->{_embedded};
    #cmp_ok scalar keys %$e, '>=', $min, "set has less than $min attributes"
    #    if defined $min;
    #cmp_ok scalar keys %$e, '<=', $max, "set has more than $max attributes"
    #    if defined $max;
    #return $e;
}


sub has_activemodel_embedded_list {
    my ($data, $key, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $e = has_activemodel_embedded($data);
    die "these HAL tests need to be rewritten to match ActiveModel";
    my $set = $e->{$key};
    # XXX these HAL tests need to be rewritten to match ActiveModel
    #if (is ref $set, "ARRAY", "_embedded has $key array") {
    #    cmp_ok scalar @$set, '>=', $min, "set has at least $min items"
    #        if defined $min;
    #    cmp_ok scalar @$set, '<=', $max, "set has at most $max items"
    #        if defined $max;
    #}
    return $set;
}



1;
