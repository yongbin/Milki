package Milki::Schema::PageLink;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

has_policy 'Milki::Schema::Policy';

has_table( Milki::Schema->Schema()->table('PageLink') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link from one page to another
