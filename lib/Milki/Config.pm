package Milki::Config;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

use File::HomeDir;
use File::Slurp qw( write_file );
use File::Temp qw( tempdir );
use Net::Interface;
use Path::Class;
use Milki::ConfigFile;

# ABSTRACT: Configuration information for Milki

1;
