package Milki::Markdent::Handler::ExtractWikiLinks;

use strict;
use warnings;
use namespace::autoclean;

use List::AllUtils qw( any );
use Milki::Types qw( HashRef );

use Moose;
use MooseX::SemiAffordanceAccessor;
use MooseX::StrictConstructor;

with 'Markdent::Role::Handler', 'Milki::Markdent::Role::WikiLinkResolver';

has links => (
    traits   => ['Hash'],
    is       => 'ro',
    isa      => HashRef [HashRef],
    init_arg => undef,
    default  => sub { {} },
    handles  => { _add_link => 'set', },
);

my @types = map { 'Milki::Markdent::Event::' . $_ }
    qw( WikiLink FileLink ImageLink );

sub handle_event {
    my $self  = shift;
    my $event = shift;

    return unless any { $event->isa($_) } @types;

    my $link_data;
    if ( $event->isa('Milki::Markdent::Event::WikiLink') ) {
        $link_data = $self->_resolve_page_link( $event->link_text() );
    }
    else {
        $link_data = $self->_resolve_file_link( $event->link_text() );
    }

    return unless $link_data && $link_data->{wiki};

    $self->_add_link( $event->link_text() => $link_data );

    return;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Extracts all links from a Milki Markdown document
