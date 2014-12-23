package Milki::Schema::UserWikiRole;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

has_policy 'Milki::Schema::Policy';

my $Schema = Milki::Schema->Schema();

has_table( $Schema->table('UserWikiRole') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a user's role in a specific wiki
