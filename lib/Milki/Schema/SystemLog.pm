package Milki::Schema::SystemLog;

use strict;
use warnings;
use namespace::autoclean;

use Milki::Schema;
use Milki::Types qw( Int );
use Storable qw( thaw nfreeze );

use Fey::ORM::Table;
use MooseX::ClassAttribute;
use MooseX::Params::Validate qw( validated_list );

my $Schema = Milki::Schema->Schema();

{
    has_policy 'Milki::Schema::Policy';

    has_table( $Schema->table('SystemLog') );

    transform data_blob => inflate { thaw( $_[1] ) } =>
        deflate { nfreeze( $_[1] ) };

    has_one( $Schema->table('User') );
    has_one( $Schema->table('Wiki') );
    has_one( $Schema->table('Page') );
}

class_has _AllLogSelect => (
    is      => 'ro',
    isa     => 'Fey::SQL::Select',
    lazy    => 1,
    builder => '_BuildAllLogSelect',
);

sub All {
    my $class = shift;
    my ( $limit, $offset ) = validated_list(
        \@_,
        limit  => { isa => Int, optional => 1 },
        offset => { isa => Int, default  => 0 },
    );

    my $select = $class->_AllLogSelect()->clone();
    $select->limit( $limit, $offset );

    my $dbh = Milki::Schema->DBIManager()->source_for_sql($select)->dbh();

    return Fey::Object::Iterator::FromSelect->new(
        classes     => 'Milki::Schema::SystemLog',
        select      => $select,
        dbh         => $dbh,
        bind_params => [$select->bind_params()],
    );
}

sub _BuildAllLogSelect {
    my $class = shift;

    my $select = Milki::Schema->SQLFactoryClass()->new_select();

    my $log_t = $Schema->table('SystemLog');

    $select->select($log_t)->from($log_t)
        ->order_by( $log_t->column('log_datetime'), 'DESC' );

    return $select;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a system log entry
