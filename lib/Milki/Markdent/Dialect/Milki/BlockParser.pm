package Milki::Markdent::Dialect::Milki::BlockParser;

use strict;
use warnings;
use namespace::autoclean;

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

extends 'Markdent::Dialect::Theory::BlockParser';

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Parses span-level markup for the Milki Markdown dialect (currently empty)
