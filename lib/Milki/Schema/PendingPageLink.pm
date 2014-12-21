package Milki::Schema::PendingPageLink;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

has_policy 'Milki::Schema::Policy';

has_table( Milki::Schema->Schema()->table('PendingPageLink') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a link to a page which does not yet exist
