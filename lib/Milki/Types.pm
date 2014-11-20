package Milki::Types;

use strict;
use warnings;

use base 'MooseX::Types::Combine';

__PACKAGE__->provide_types_from(
    qw(
        Milki::Types::Internal
        MooseX::Types::Moose
        MooseX::Types::Path::Class
        )
);

# ABSTRACT: Exports Milki types as well as Moose and Path::Class types

1;
