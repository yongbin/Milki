use strict;
use warnings;

use Test::Differences;
use Test::More;

use lib 't/lib';
use Milki::Test::FakeSchema;

use Milki::Formatter::HTMLToWiki;
use Milki::Schema::File;
use Milki::Schema::Wiki;

my $wiki = Milki::Schema::Wiki->new(
    wiki_id     => 1,
    short_name  => 'first-wiki',
    title       => 'First Wiki',
    _from_query => 1,
);

my $formatter = Milki::Formatter::HTMLToWiki->new( wiki => $wiki );

{
    my $html = <<'EOF';
<h2 id="welcometoyournewwiki">Welcome to your new wiki</h2>

<p>A <a href="http://www.vegguide.org">wiki</a> is a set of web pages</p>
<p><a href="http://www.vegguide.org">http://www.vegguide.org</a></p>
<p><strong>that can</strong> <em>be</em> read and edited by a group of people.</p>
<p>You use simple syntax to add things like <em>italics</em> and <strong>bold</strong></p>
<p>to the text. Wikis are designed to make linking to other pages easy.</p>
<p>See the <a class="existing-page" href="/wiki/first-wiki/page/Help">Help</a> page.</p>
<p>See the <a class="existing-page" href="/wiki/first-wiki/page/Help">instructions</a> page.</p>
<p>See the <a class="existing-page" href="/wiki/second-wiki/page/Front_Page">Front Page</a>.</p>
<p>See the <a class="existing-page" href="/wiki/second-wiki/page/Front_Page">Second Wiki</a>.</p>
<p><a href="/wiki/first-wiki/file/1">foo.txt</a></p>
<p><a href="/wiki/first-wiki/file/1">File link</a></p>
<p><a href="/wiki/second-wiki/file/1">foo.txt</a></p>
<p><a href="/wiki/second-wiki/file/1">File link</a></p>
<p><a href="/wiki/first-wiki/file/2">bad file</a></p>
<p><a href="/wiki/second-wiki/recent">recent changes</a></p>

<ol>
  <li>
    num</li>
  <li>
    list
    <ol>
      <li>
        2nd level</li>
    </ol>
  </li>
</ol>

<ul>
  <li>
    Unordered list</li>
  <li>
    Item 2</li>
</ul>

<ul>
  <li>UL</li>
  <li>more
    <ul>
      <li>2nd level</li>
    </ul>
  </li>
</ul>

<p>blah</p>

<ul>
  <li>
    blah</li>
</ul>

<p>plain text</p>

<p>This is <code>code</code> and not</p>

<p>
<a name="empty"></a><a name="empty">no href</a>
</p>

<blockquote>
  <blockquote>
    <blockquote>
      <p>indented</p>
    </blockquote>
  </blockquote>
</blockquote>
EOF

    no warnings 'redefine';
    local *Milki::Schema::File::new = sub {
        shift;

        my %p = @_;

        if ( $p{file_id} == 1 ) {
            return bless { file_id => 1, filename => 'foo.txt', },
                'Milki::Schema::File';
        }
        else {
            return;
        }
    };

    my $wikitext = $formatter->html_to_wikitext($html);

    my $expected = <<'EOF';
## Welcome to your new wiki

A [wiki](http://www.vegguide.org) is a set of web pages

<http://www.vegguide.org>

**that can** _be_ read and edited by a group of people.

You use simple syntax to add things like _italics_ and **bold**

to the text. Wikis are designed to make linking to other pages easy.

See the [[Help]] page.

See the [[Help]]{instructions} page.

See the [[second-wiki/Front Page]].

See the [[second-wiki/Front Page]]{Second Wiki}.

[[file:1]]

[[file:1]]{File link}

[[second-wiki/file:1]]

[[second-wiki/file:1]]{File link}

[[file:2]]{bad file}

[recent changes](/wiki/second-wiki/recent)

1.  num
1.  list 
    1.  2nd level



*  Unordered list
*  Item 2

* UL
* more 
    * 2nd level



blah

*  blah

plain text

This is `code` and not

no href

> > > indented

EOF

    eq_or_diff( $wikitext, $expected,
        'wikitext matches expected html -> wikitext result' );
}

{
    my $html = <<'EOF';
<table>
  <thead>
    <tr>
      <th>Head 1</th>
      <th>Head 2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>B1</td>
      <td>B2</td>
    </tr>
    <tr>
      <td>B3</td>
      <td>B4</td>
    </tr>
  </tbody>
</table>
EOF

    my $wikitext = $formatter->html_to_wikitext($html);

    my $expected = <<'EOF';
+----------+----------+
| Head 1   | Head 2   |
+----------+----------+
| B1       | B2       |
| B3       | B4       |
+----------+----------+
EOF

    eq_or_diff( $wikitext, $expected, 'html to wikitext - simple table' );
}

{
    my $html = <<'EOF';
<table>
  <thead>
    <tr>
      <th>Head 1</th>
      <th>Head 2</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>B1</td>
      <td>B2</td>
    </tr>
  </tbody>
  <tbody>
    <tr>
      <td>B3</td>
      <td>B4</td>
    </tr>
  </tbody>
</table>
EOF

    my $wikitext = $formatter->html_to_wikitext($html);

    my $expected = <<'EOF';
+----------+----------+
| Head 1   | Head 2   |
+----------+----------+
| B1       | B2       |

| B3       | B4       |
+----------+----------+
EOF

    eq_or_diff( $wikitext, $expected,
        'html to wikitext - table with two tbody tags' );
}
{
    my $html = <<'EOF';
<table>
  <tr>
    <th>Head 1</th>
    <th>Head 2</th>
  </tr>
  <tr>
    <td>B1</td>
    <td>B2</td>
  </tr>
  <tr>
    <td>B3</td>
    <td>B4</td>
  </tr>
</table>
EOF

    my $wikitext = $formatter->html_to_wikitext($html);

    my $expected = <<'EOF';
+----------+----------+
| Head 1   | Head 2   |
+----------+----------+
| B1       | B2       |
| B3       | B4       |
+----------+----------+
EOF

    eq_or_diff( $wikitext, $expected,
        'html to wikitext - table with no thead or tbody tags' );
}

{
    is( $formatter->html_to_wikitext(q{}),
        q{}, 'formatter handles empty string properly' );
}

{
    is( $formatter->html_to_wikitext('foo'),
        "foo\n",
        'formatter always adds a newline to the end of the returned string' );
}

{
    my $html = '<p>foo <!-- a comment --></p>';

    my $expected = "foo <!-- a comment -->\n\n";

    my $wikitext = $formatter->html_to_wikitext($html);

    eq_or_diff( $wikitext, $expected,
        'formatter outputs comment in html verbatim' );
}

done_testing();
