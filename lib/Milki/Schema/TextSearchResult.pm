package Milki::Schema::TextSearchResult;

use strict;
use warnings;
use namespace::autoclean;

use HTML::Entities qw( encode_entities );
use Milki::Schema::Page;
use Milki::Schema::Wiki;
use Milki::Types qw( Str );

use Moose;

has _result =>
    ( is => 'ro', isa => Str, required => 1, init_arg => 'result', );

# The marker needs to be something that is unlikely to ever appear in normal
# text, does not look like wikitext, and will not changed when HTML-escaped.
sub HighlightMarker {
    return '$@$@$@$';
}

sub title_for_display {
    my $self       = shift;
    my $full_title = shift;

    my ( $title, undef ) = split /\n/, $self->_result(), 2;

    my $marker = $self->HighlightMarker();
    return encode_entities($full_title) unless $title =~ /\Q$marker/;

    my ($matched) = $title =~ m{\Q$marker\E(.+?)\Q$marker};

    $full_title = encode_entities($full_title);
    $full_title =~ s{\Q$matched}{<strong>$matched</strong>};

    return $full_title;
}

sub body_for_display {
    my $self = shift;

    my ( undef, $text ) = split /\n/, $self->_result(), 2;

    my $marker = $self->HighlightMarker();

    $text = encode_entities($text);

    $text =~ s{\Q$marker\E(.+?)\Q$marker}{<strong>$1</strong>}g;

    $text =~ s/\n\n/&nbsp;&nbsp;/g;

    return $text;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a text search result
