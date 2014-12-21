package Milki::Schema::PageTag;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

my $Schema = Milki::Schema->Schema();

{
    has_policy 'Milki::Schema::Policy';

    has_table( $Schema->table('PageTag') );
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a tag for a page
