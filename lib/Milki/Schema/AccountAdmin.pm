package Milki::Schema::AccountAdmin;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;

has_policy 'Milki::Schema::Policy';

my $Schema = Milki::Schema->Schema();

has_table( $Schema->table('AccountAdmin') );

__PACKAGE__->meta()->make_immutable();

1;

__END__


