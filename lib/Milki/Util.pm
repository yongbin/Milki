package Milki::Util;

use strict;
use warnings;

use Exporter qw( import );

our @EXPORT_OK = qw( string_is_empty studly_to_calm english_list );

sub string_is_empty {
    return 1 if !defined $_[0] || !length $_[0];
    return 0;
}

sub english_list {
    return $_[0] if @_ <= 1;

    return join ' and ', @_ if @_ == 2;

    my $last = pop @_;

    return ( join ', ', @_ ) . ', and ' . $last;
}

1;

# ABSTRACT: A utility module
