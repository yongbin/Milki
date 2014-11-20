package Milki::ConfigFile;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

use Config::INI::Reader;
use Path::Class;
use Milki::Types qw( Dir File HashRef Maybe );

# ABSTRACT: Low-level interface to the config file

1;
