package Milki::Markdent::Event::WikiLink;

use strict;
use warnings;
use namespace::autoclean;

use Markdent::Types qw( Str );

use Moose;
use MooseX::StrictConstructor;

has link_text => ( is => 'ro', isa => Str, required => 1, );

has display_text =>
    ( is => 'ro', isa => Str, predicate => 'has_display_text', );

with 'Markdent::Role::Event';

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link to a wiki page
