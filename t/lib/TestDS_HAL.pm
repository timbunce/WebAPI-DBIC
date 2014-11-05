package TestDS_HAL;

use Test::Most;
use TestDS;
use Devel::Dwarn;
use Carp;

use parent 'Exporter';


our @EXPORT = qw(
    dsreq_hal
    has_hal_embedded
    has_hal_embedded_list
);


sub dsreq_hal {
    my ($method, $uri, $headers, $data) = @_;
    my @headers = (
        'Content-Type' => 'application/hal+json',
        'Accept' => 'application/hal+json,application/json',
        @{$headers || []}
    );
    return dsreq($method, $uri, \@headers, $data);
}


sub has_hal_embedded {
    my ($data, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    is ref $data, 'HASH', "data isn't a hash";
    is ref $data->{_embedded}, 'HASH', "_embedded isn't hash" or diag $data;
    my $e = $data->{_embedded};
    cmp_ok scalar keys %$e, '>=', $min, "set has less than $min attributes"
        if defined $min;
    cmp_ok scalar keys %$e, '<=', $max, "set has more than $max attributes"
        if defined $max;
    return $e;
}


sub has_hal_embedded_list {
    my ($data, $key, $min, $max) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my $e = has_hal_embedded($data);
    my $set = $e->{$key};
    if (is ref $set, "ARRAY", "_embedded has $key array") {
        cmp_ok scalar @$set, '>=', $min, "set has at least $min items"
            if defined $min;
        cmp_ok scalar @$set, '<=', $max, "set has at most $max items"
            if defined $max;
    }
    return $set;
}



1;
