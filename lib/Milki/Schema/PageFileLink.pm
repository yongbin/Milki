package Milki::Schema::PageFileLink;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

has_policy 'Milki::Schema::Policy';

has_table( Milki::Schema->Schema()->table('PageFileLink') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link from a page to a file
