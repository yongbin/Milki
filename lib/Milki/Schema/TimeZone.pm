package Milki::Schema::TimeZone;

use strict;
use warnings;
use namespace::autoclean;

use Fey::Object::Iterator::FromSelect;
use Milki::Schema;

use Fey::ORM::Table;

my $Schema = Milki::Schema->Schema();

{
    has_policy 'Milki::Schema::Policy';

    has_table( $Schema->table('TimeZone') );

    has_one( $Schema->table('Country') );
}

sub CreateDefaultZones {
    my $class = shift;

    my %zones = (
        us => [
            ['America/New_York',      'East Coast'],
            ['America/Chicago',       'Central'],
            ['America/Denver',        'Mountain'],
            ['America/Los_Angeles',   'West Coast'],
            ['America/Anchorage',     'Alaska'],
            ['Pacific/Honolulu',      'Hawaii'],
            ['America/Santo_Domingo', 'Puerto Rico'],
        ],

        ca => [
            ['America/Halifax',   'Halifax and New Brunswick'],
            ['America/Toronto',   'Ontario and Quebec'],
            ['America/Winnipeg',  'Manitoba'],
            ['America/Regina',    'Saskatchewan'],
            ['America/Edmonton',  'Alberta'],
            ['America/Vancouver', 'British Columbia'],
            ['America/St_Johns',  q{St. John's}],
        ],
    );

    for my $iso_code ( keys %zones ) {
        my $order = 1;

        for my $zone ( @{ $zones{$iso_code} } ) {
            next if $class->new( olson_name => $zone->[0] );

            $class->insert(
                olson_name    => $zone->[0],
                iso_code      => $iso_code,
                description   => $zone->[1],
                display_order => $order++,
            );
        }
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a time zone
