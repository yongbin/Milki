package Milki::Localize::Gettext;

use strict;
use warnings;
use namespace::autoclean;

use feature ':5.10';

use Milki::Localize::Format::Gettext;

use Moose;

extends 'Data::Localize::Gettext';

# Overrides parent to do parent locale lookup and return id if no msgstr is
# found
sub get_lexicon {
    my $self = shift;
    my $lang = shift;
    my $id   = shift;

    my $lexicon;
    until ( $lexicon = $self->get_lexicon_map($lang) ) {
        $lang = $self->_parent_lang($lang);
        last unless $lang;
    }

    return () unless $lexicon;

    return $lexicon->get($id) || $id;
}

# The parsing of locale codes and fallback logic is borrowed from LDML.pm in
# the DateTime::Locale distro.
sub _parent_lang {
    my $self = shift;
    my $lang = shift;

    my @parts = $self->_parse_lang($lang);

    pop @parts;

    return join '_', @parts;
}

sub _parse_lang {
    my $self = shift;
    my $lang = shift;

    return grep {defined} $lang =~ /([a-z]+)                  # language
                                    (?: [-_]([A-Z][a-z]+) )?  # script - Title Case - optional
                                    (?: [-_]([A-Z]+) )?       # territory - ALL CAPS - optional
                                    (?: [-_]([A-Z]+) )?       # variant - ALL CAPS - optional
                                   /x;
}

sub _build_formatter {
    return Milki::Localize::Format::Gettext->new();
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: A subclass of Data::Localize::Gettext
