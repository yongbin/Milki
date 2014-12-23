package Milki::Formatter::WikiToHTML;

use strict;
use warnings;
use namespace::autoclean;

use Markdent::Handler::HTMLFilter;
use Markdent::Parser;
use Milki::Markdent::Dialect::Milki::BlockParser;
use Milki::Markdent::Dialect::Milki::SpanParser;
use Milki::Markdent::Handler::HTMLStream;

use Moose;
use MooseX::StrictConstructor;

has _user => (
    is       => 'ro',
    isa      => 'Milki::Schema::User',
    required => 1,
    init_arg => 'user',
);

has _wiki => (
    is       => 'ro',
    isa      => 'Milki::Schema::Wiki',
    required => 1,
    init_arg => 'wiki',
);

sub wiki_to_html {
    my $self = shift;
    my $text = shift;

    my $buffer = q{};
    open my $fh, '>', \$buffer;

    my $html = Milki::Markdent::Handler::HTMLStream->new(
        output => $fh,
        wiki   => $self->_wiki(),
        user   => $self->_user()
    );

    my $filter = Markdent::Handler::HTMLFilter->new( handler => $html );

    my $parser = Markdent::Parser->new(
        dialect => 'Milki::Markdent::Dialect::Milki',
        handler => $filter,
    );

    $parser->parse( markdown => $text );

    return $buffer;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Turns wikitext into HTML

