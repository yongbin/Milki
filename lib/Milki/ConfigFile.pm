package Milki::ConfigFile;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

use Config::INI::Reader;
use Path::Class;
use Milki::Types qw( Dir File HashRef Maybe );
use Milki::Util qw( string_is_empty );

use Moose;
use MooseX::StrictConstructor;

has file => (
    is      => 'rw',
    isa     => Maybe [File],
    lazy    => 1,
    builder => '_build_file',
    writer  => '_set_file',
    clearer => '_clear_file',
);

has raw_data => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_raw_data',
    writer  => '_set_raw_data',
    clearer => '_clear_raw_data',
);

has _home_dir => ( is => 'ro', isa => Dir, init_arg => 'home_dir', );

sub _build_file {
    my $self = shift;

    if ( !string_is_empty( $ENV{MILKI_CONFIG} ) ) {
        die
            "Nonexistent config file in MILKI_CONFIG env var: $ENV{MILKI_CONFIG}"
            unless -f $ENV{MILKI_CONFIG};

        return file( $ENV{MILKI_CONFIG} );
    }

    return if $ENV{MILKI_CONFIG_TESTING};

    my @dirs = dir('/etc/milki');
    push @dirs, $self->_home_dir()->subdir( '.milki', 'etc' )
        if $> && $self->_home_dir();

    for my $dir (@dirs) {
        my $file = $dir->file('milki.conf');

        return $file if -f $file;
    }

    return;
}

sub _build_raw_data {
    my $self = shift;

    my $file = $self->file() or return {};

    return Config::INI::Reader->read_file($file) || {};
}

__PACKAGE__->meta()->make_immutable;

# ABSTRACT: Low-level interface to the config file

1;
