package Milki::Schema::WikiRolePermission;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;

use Fey::ORM::Table;
use MooseX::ClassAttribute;

has_policy 'Milki::Schema::Policy';

has_table( Milki::Schema->Schema()->table('WikiRolePermission') );

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents the permission granted to a role in a specific wiki
