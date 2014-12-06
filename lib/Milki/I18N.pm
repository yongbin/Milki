package Milki::I18N;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT = qw( loc );

use Data::Localize;
use Path::Class qw( file );
use Milki::Config;

{
    my $DL = Data::Localize->new( fallback_languages => ['en'] );
    $DL->add_localizer(
        class      => '+Milki::Localize::Gettext',
        path       => file( Milki::Config->new()->share_dir, 'i18n', '*.po' ),
        keep_empty => 1,
    );

    sub SetLanguage {
        shift;
        $DL->set_languages(@_);
    }

    sub Language {
        shift;
        ( $DL->languages )[0];
    }

    sub loc {
        $DL->localize(@_);
    }
}

1;

# ABSTRACT: The primary interface to i18n
