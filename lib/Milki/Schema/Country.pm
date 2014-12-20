package Milki::Schema::Country;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

my $Schema = Milki::Schema->Schema();

{
    has_policy 'Milki::Schema::Policy';

    has_table( $Schema->table('Country') );

    has_one( $Schema->table('Locale') );

    has_many time_zones => (
        table => $Schema->table('TimeZone'),
        order_by =>
            [$Schema->table('TimeZone')->column('display_order'), 'ASC'],
    );
}

sub CreateDefaultCountries {
    my $class = shift;

    my @countries
        = ( ['us', 'United States', 'en_US'], ['ca', 'Canada', 'en_CA'], );

    for my $country (@countries) {
        next if $class->new( iso_code => $country->[0] );

        $class->insert(
            iso_code    => $country->[0],
            name        => $country->[1],
            locale_code => $country->[2],
        );
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a country
