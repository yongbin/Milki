package Milki::Schema::Policy;

use strict;
use warnings;

use DateTime::Format::Pg;
use Lingua::EN::Inflect qw( PL_N );
use Scalar::Util qw( blessed );

use Fey::ORM::Policy;

transform_all matching { $_[0]->name() =~ /_datetime$/ } => deflate {
    blessed $_[1] && $_[1]->isa('DateTime')
        ? DateTime::Format::Pg->format_datetime( $_[1] )
        : $_[1];
} => inflate {
    return $_[1] unless defined $_[1];
    my $dt = DateTime::Format::Pg->parse_datetime( $_[1] );
    $dt->set_time_zone('UTC');
    return $dt;
};

transform_all matching { $_[0]->name() =~ /_date$/ } => deflate {
    blessed $_[1] && $_[1]->isa('DateTime')
        ? DateTime::Format::Pg->format_date( $_[1] )
        : $_[1];
} => inflate {
    return $_[1] unless defined $_[1];
    my $dt = DateTime::Format::Pg->parse_date( $_[1] );
    $dt->set_time_zone('UTC');
    return $dt;
};

has_one_namer {
    my $name = $_[0]->name();
    my @parts = map {lc} ( $name =~ /([A-Z][a-z]+)/g );

    return join q{_}, @parts;
};

has_many_namer {
    my $name = $_[0]->name();
    my @parts = map {lc} ( $name =~ /([A-Z][a-z]+)/g );

    $parts[-1] = PL_N( $parts[-1] );

    return join q{_}, @parts;
};

1;

# ABSTRACT: A Fey::Policy for Milki
