package Milki::Exceptions;

use strict;
use warnings;

my %E;

BEGIN {
    %E = (
        'Milki::Exception' => {
            alias       => 'error',
            description => 'Generic super-class for Milki exceptions'
        },

        'Milki::Exception::DataValidation' => {
            isa         => 'Milki::Exception',
            alias       => 'data_validation_error',
            fields      => ['errors'],
            description => 'Invalid data given to a method/function'
        },
    );
}

{

    package Milki::Exception::DataValidation;

    sub messages { @{ $_[0]->errors || [] } }

    sub full_message {
        if ( my @m = $_[0]->messages ) {
            return join "\n", 'Data validation errors: ',
                map { ref $_ ? $_->{message} : $_ } @m;
        }
        else {
            return $_[0]->SUPER::full_message();
        }
    }
}

use Exception::Class (%E);

Milki::Exception->Trace(1);

use Exporter qw( import );

our @EXPORT_OK = map { $_->{alias} || () } values %E;

1;

# ABSTRACT: Exception classes used by Milki
