package Markdent::Types::Internal;
$Markdent::Types::Internal::VERSION = '0.21';
use strict;
use warnings;

use IO::Handle;

use MooseX::Types 0.20 -declare => [
    qw(
        BlockParserClass
        EventObject
        HandlerObject
        HeaderLevel
        NonEmptyArrayRef
        OutputStream
        PosInt
        SpanParserClass
        TableCellAlignment
        )
];

use MooseX::Types::Moose qw(
    ArrayRef
    ClassName
    FileHandle
    Int
    Item
    Object
);

#<<<
subtype HeaderLevel,
    as Int,
    where { $_ >= 1 && $_ <= 6 },
    message { "Header level must be a number from 1-6 (not $_)" };

subtype BlockParserClass,
    as ClassName,
    where { $_->can('does') && $_->does('Markdent::Role::BlockParser') };

subtype SpanParserClass,
    as ClassName,
    where { $_->can('does') && $_->does('Markdent::Role::SpanParser') };

subtype EventObject,
    as Object,
    where { $_->can('does') && $_->does('Markdent::Role::Event') };

subtype HandlerObject,
    as Object,
    where { $_->can('does') && $_->does('Markdent::Role::Handler') };

subtype NonEmptyArrayRef,
    as ArrayRef,
    where { @{$_} >= 1 };

subtype OutputStream,
    as Item,
    where {
        FileHandle->check($_)
            || ( Object->check($_) && $_->can('print') );
    },
    message { 'The output stream must be a Perl file handle or an object with a print method' };

enum TableCellAlignment, qw( left right center );

subtype PosInt,
    as Int,
    where { $_ >= 1 },
    message { "The number provided ($_) is not a positive integer" };
#>>>

1;
