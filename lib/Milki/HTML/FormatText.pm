package Milki::HTML::FormatText;

use strict;
use warnings;

use base 'HTML::FormatText';

# If these subs don't return true, the formatter won't recurse into the node
# for text/etc.

sub a_start {
    my $self = shift;
    my $node = shift;

    $self->{uri_for_a} = $node->attr('href');

    return 1;
}

sub a_end {
    my $self = shift;
    my $node = shift;

    $self->out( ' (' . $self->{uri_for_a} . ')' ) if $self->{uri_for_a};

    delete $self->{uri_for_a};

    return 1;
}

1;

# ABSTRACT: A subclass of HTML::FormatText that also handles links
