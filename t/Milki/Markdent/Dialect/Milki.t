use strict;
use warnings;

use Test::Markdent;
use Test::Most;

use lib 't/lib';

use Milki::Markdent::Handler::MinimalTree;
use Milki::Markdent::Dialect::Milki::BlockParser;
use Milki::Markdent::Dialect::Milki::SpanParser;

{
    my $wikitext = <<'EOF';
A plain ((Wiki Link)).
EOF

    my $expect = [
        { type => 'paragraph', },
        [
            { type => 'text',      text      => "A plain ", },
            { type => 'wiki_link', link_text => 'Wiki Link', },
            { type => 'text',      text      => ".\n", },
        ],
    ];

    parse_ok(
        {
            dialect       => 'Milki::Markdent::Dialect::Milki',
            handler_class => 'Milki::Markdent::Handler::MinimalTree',
        },
        $wikitext,
        $expect,
        'simple wiki link'
    );
}

{
    my $wikitext = <<'EOF';
A plain [display text]((Wiki Link)).
EOF

    my $expect = [
        { type => 'paragraph', },
        [
            { type => 'text', text => "A plain ", },
            {
                type         => 'wiki_link',
                link_text    => 'Wiki Link',
                display_text => 'display text',
            },
            { type => 'text', text => ".\n", },
        ],
    ];

    parse_ok(
        {
            dialect       => 'Milki::Markdent::Dialect::Milki',
            handler_class => 'Milki::Markdent::Handler::MinimalTree',
        },
        $wikitext,
        $expect,
        'wiki link with display text'
    );
}

{
    my $wikitext = <<'EOF';
Some file - {{file: foo.pdf}}
EOF

    my $expect = [
        { type => 'paragraph', },
        [
            { type => 'text',      text      => "Some file - ", },
            { type => 'file_link', link_text => 'foo.pdf', },
            { type => 'text',      text      => "\n", },
        ],
    ];

    parse_ok(
        {
            dialect       => 'Milki::Markdent::Dialect::Milki',
            handler_class => 'Milki::Markdent::Handler::MinimalTree',
        },
        $wikitext,
        $expect,
        'simple file link'
    );
}

{
    my $wikitext = <<'EOF';
a [special pdf]{{file: foo.pdf}}
EOF

    my $expect = [
        { type => 'paragraph', },
        [
            { type => 'text', text => "a ", },
            {
                type         => 'file_link',
                link_text    => 'foo.pdf',
                display_text => 'special pdf',
            },
            { type => 'text', text => "\n", },
        ],
    ];

    parse_ok(
        {
            dialect       => 'Milki::Markdent::Dialect::Milki',
            handler_class => 'Milki::Markdent::Handler::MinimalTree',
        },
        $wikitext,
        $expect,
        'file link with display_text'
    );
}

{
    my $wikitext = <<'EOF';
Some image - {{image: foo.png}}
EOF

    my $expect = [
        { type => 'paragraph', },
        [
            { type => 'text',       text      => "Some image - ", },
            { type => 'image_link', link_text => 'foo.png', },
            { type => 'text',       text      => "\n", },
        ],
    ];

    parse_ok(
        {
            dialect       => 'Milki::Markdent::Dialect::Milki',
            handler_class => 'Milki::Markdent::Handler::MinimalTree',
        },
        $wikitext,
        $expect,
        'simple image link'
    );
}

done_testing();
