package Milki::Markdent::Event::ImageLink;

use strict;
use warnings;
use namespace::autoclean;

use Markdent::Types qw( Str );

use Moose;
use MooseX::StrictConstructor;

has link_text => ( is => 'ro', isa => Str, required => 1, );

with 'Markdent::Role::Event';

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link to an image (to be embedded in the page)
