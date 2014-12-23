package Milki::Schema::Role;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_policy 'Milki::Schema::Policy';

has_table( Milki::Schema->Schema()->table('Role') );

# For i18n purposes:
# loc( 'Guest' )
# loc( 'Authenticated' )
# loc( 'Member' )
# loc( 'Admin' )

for my $role (qw( Guest Authenticated Member Admin )) {
    class_has $role => (
        is      => 'ro',
        isa     => 'Milki::Schema::Role',
        lazy    => 1,
        default => sub { __PACKAGE__->_CreateOrFindRole($role) },
    );
}

sub _CreateOrFindRole {
    my $class = shift;
    my $name  = shift;

    my $role = eval { $class->new( name => $name ) };

    $role ||= $class->insert( name => $name );

    return $role;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a role
