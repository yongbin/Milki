package Milki::DBInstaller;

use strict;
use warnings;
use autodie qw( :all );

use lib 'lib';

use DBI;
use Fey::DBIManager::Source;
use File::Slurp qw( read_file);
use File::Temp qw( tempdir);
use Path::Class qw( file );

use Moose;
use MooseX::StrictConstructor;

with 'MooseX::Getopt';

has name =>
    ( is => 'rw', writer => '_set_name', isa => 'Str', required => 1, );

for my $attr (qw( username password host port )) {
    has $attr => ( is => 'rw', writer => '_set_' . $attr, isa => 'Str', );
}

has _existing_config => (
    is      => 'ro',
    isa     => 'HashRef[Str]',
    lazy    => 1,
    builder => '_build_existing_config',
);

has db_exists => (
    traits  => ['NoGetopt'],
    is      => 'ro',
    isa     => 'Bool',
    lazy    => 1,
    builder => '_build_db_exists',
);

has drop => ( is => 'ro', isa => 'Bool', default => 0, );

has seed => ( is => 'ro', isa => 'Bool', default => 1, );

has production => ( is => 'ro', isa => 'Bool', default => 0, );

has quiet => ( is => 'ro', isa => 'Bool', default => 0, );

sub BUILD {
    my $self = shift;
    my $p    = shift;

    my $existing = $self->_existing_config();
    unless ( exists $p->{name} ) {
        die
            "No name provided to the constructor and no name available from an existing Milki config file."
            unless $existing->{name};

        $self->_set_name( $p->{name} );
    }

    for my $attr (qw( username password host port )) {
        my $set = '_set_' . $attr;

        $self->$set( $existing->{$attr} ) if defined $existing->{$attr};
    }

    return;
}

sub run {
    my $self = shift;

    if ( !$self->drop() && $self->db_exists() ) {
        warn
            qq{\n  Will not drop a database unless you pass the --drop argument.\n\n};
        exit 1;
    }

    print "\n";
    $self->_drop_and_create_db();
    $self->_build_db();

    exit 0 unless $self->seed();

    $self->_seed_data();
}

sub update_or_install_db {
    my $self = shift;

    unless ( $self->_can_connect() ) {
        my $msg
            = "\n  Cannot connect to Postgres with the connection info provided:\n\n";
        $msg .= sprintf( "    %13s = %s\n", 'database name', $self->name() );

        for my $key (qw( username password host port )) {
            my $val = $self->$key();
            next unless defined $val;

            $msg .= sprintf( "  %13s = %s\n", $key, $val );
        }

        $msg
            .= "\n  You can change connection info settings by passing arguments to 'perl Build.PL'\n";
        $msg .= "  See the INSTALL documentation for details.\n\n";

        warn $msg;
        return;
    }

    my $version = $self->_get_installed_version();

    print "\n" unless $self->quiet();

    my $name = $self->name();
    $self->_msg(
        "Installing/updating your Milki database (database name = $name).");

    if ( !defined $version ) {
        $self->_msg("Installing a fresh database.");
        $self->_drop_and_create_db();
        $self->_build_db();
        $self->_seed_data() if $self->seed();
    }
    else {
        my $next_version = $self->_get_next_version();

        if ( $version == $next_version ) {
            $self->_msg("Your Milki database is up-to-date.");
            return;
        }

        $self->_msg(
            "Migrating your Milki database from version $version to $next_version."
        );

        $self->_migrate_db( $version, $next_version );
    }
}

sub _can_connect {
    my $self = shift;

    my $dsn = $self->_make_dsn('template1');

    DBI->connect( $dsn, $self->username(), $self->password(),
        { PrintError => 0, PrintWarn => 0 } );
}

sub _build_db_exists {
    my $self = shift;

    eval { $self->_make_dbh() } && return 1;

    die $@ if $@ and $@ !~ /database "\w+" does not exist/;

    return 0;
}

sub _get_installed_version {
    my $self = shift;

    my $dbh = eval { $self->_make_dbh() } or return;

    my $row = $dbh->selectrow_arrayref(q{SELECT version FROM "Version"});

    return $row->[0] if $row;
}

sub _make_dbh {
    my $self = shift;

    my %source = ( dsn => $self->_make_dsn() );

    $source{username} = $self->username() if defined $self->username();

    $source{password} = $self->password() if defined $self->password();

    return Fey::DBIManager::Source->new(%source)->dbh();
}

sub _make_dsn {
    my $self = shift;
    my $name = shift || $self->name();

    my $dsn = 'dbi:Pg:dbname=' . $name;

    $dsn .= ';host=' . $self->host() if defined $self->host();

    $dsn .= ';port=' . $self->port() if defined $self->port();

    return $dsn;
}

sub _build_existing_config {
    my $self = shift;

    require Milki::Config;

    my $instance = Milki::Config->instance();

    return {} unless $instance->config_file();

    return {
        map {
            my $attr = 'database_' . $_;
            $instance->$attr() ? ( $_ => $instance->$attr() ) : ()
        } qw( name username password host port )
    };
}

sub _get_next_version {
    my $self = shift;

    my $file = file(qw( schema Milki.sql ));

    my ($version_insert)
        = grep {/INSERT INTO "Version"/}
        read_file( $file->resolve()->stringify() );

    my ($next_version) = $version_insert =~ /VALUES \((\d+)\)/;

    die "Cannot find a version in the current schema!" unless $next_version;

    return $next_version;
}

sub _drop_and_create_db {
    my $self = shift;

    my $name = $self->name();

    $self->_msg(
        "Dropping (if necessary) and creating the Milki database (database name = $name)"
    );

    my $commands = <<"EOF";
SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "$name";

EOF

    $commands .= qq{CREATE DATABASE "$name" ENCODING 'UTF8'};
    $commands .= ' OWNER ' . $self->username() if defined $self->username();
    $commands .= q{;};

    local $ENV{PGPASSWORD} = $self->password();

    # When trying to issue a DROP with -c (command), you cannot also set
    # client_min_messages, so we make a temp file and feed it in with -f.
    my $dir = tempdir( CLEANUP => 1 );
    my $file = file( $dir, 'recreate-db.sql' );

    open my $fh, '>', $file;
    print {$fh} $commands;
    close $fh;

    system( 'psql', 'template1', $self->_psql_args(), '-q', '-w', '-f',
        $file );
}

sub _build_db {
    my $self = shift;

    my $schema_file = file( 'schema', 'Milki.sql' );

    $self->_msg("Creating schema from $schema_file");

    local $ENV{PGPASSWORD} = $self->password();

    system( 'psql', $self->name(), $self->_psql_args(), '-q', '-w', '-f',
        $schema_file )
        and die 'Cannot create Milki database with psql';
}

sub _psql_args {
    my $self = shift;

    my @args;

    if ( $self->username() ) {
        push @args, '-U', $self->username();
    }

    if ( $self->host() ) {
        push @args, '-h', $self->host();
    }

    if ( $self->port() ) {
        push @args, '-p', $self->port();
    }

    return @args;
}

sub _seed_data {
    my $self = shift;

    require Milki::Config;

    my $config = Milki::Config->instance();
    $config->_set_database_name( $self->name() );

    for my $key (qw( username password host port )) {
        if ( my $val = $self->$key() ) {
            my $set_meth = '_set_database_' . $key;

            $config->$set_meth($val);
        }
    }

    require Milki::SeedData;

    my $name = $self->name();
    $self->_msg("Seeding the $name database");

    Milki::SeedData::seed_data(
        production => $self->production(),
        verbose    => !$self->quiet()
    );
}

sub _msg {
    my $self = shift;

    return if $self->quiet();

    my $msg = shift;

    print "  $msg\n\n";
}

1;
