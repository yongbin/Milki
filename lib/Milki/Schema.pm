package Milki::Schema;

use strict;
use warnings;
use namespace::autoclean;

use Carp;
use DBI;
use Fey::ORM::Schema;
use Fey::DBIManager::Source;
use Fey::Loader;
use Milki::Config;

#use Milki::I18N;

if ($Milki::Schema::TestSchema) {
    has_schema($Milki::Schema::TestSchema);

    require DBD::Mock;

    my $source = Fey::DBIManager::Source->new( dsn => 'dbi:Mock:' );

    $source->dbh()->{HandleError} = sub { Carp::confess(shift); };

    __PACKAGE__->DBIManager()->add_source($source);
}
else {
    my $dbi_config = Milki::Config->instance()->dbi_config();

    my $source = Fey::DBIManager::Source->new( %{$dbi_config},
        post_connect => \&_set_dbh_attributes, );

    my $schema = Fey::Loader->new( dbh => $source->dbh() )->make_schema();

    has_schema $schema;

    __PACKAGE__->DBIManager()->add_source($source);
}

sub _set_dbh_attributes {
    my $dbh = shift;

    $dbh->{pg_enable_utf8} = 1;

    $dbh->do('SET TIME ZONE UTC');

    $dbh->{HandleError} = sub { Carp::confess(shift) };

    return;
}

sub LoadAllClasses {
    my $class = shift;

    for my $table ( $class->Schema()->tables() ) {
        my $class = 'Milki::Schema::' . $table->name();

        ( my $path = $class ) =~ s{::}{/}g;

        eval "use $class";
        die $@ if $@ && $@ !~ /\Qcan't locate $path/i;
    }
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents the Milki schema
