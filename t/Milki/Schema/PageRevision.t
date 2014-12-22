use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Milki::Test::RealSchema;

use Milki::Schema::Page;
use Milki::Schema::PageRevision;
use Milki::Schema::User;
use Milki::Schema::Wiki;

my $wiki = Milki::Schema::Wiki->new( short_name => 'first-wiki' );
my $user = Milki::Schema::User->GuestUser();

{
    my $page = Milki::Schema::Page->insert_with_content(
        title   => 'Some Page',
        content => 'This is a page with a link to a ((Pending Page))',
        user_id => $user->user_id(),
        wiki_id => $wiki->wiki_id(),
    );

    my $rev1     = $page->most_recent_revision();
    my $page_uri = $page->uri();

    is(
        $rev1->uri(),
        "$page_uri/revision/" . $rev1->revision_number(),
        'got expected uri for page revision'
    );

    my $html = <<'EOF';
<p>This is a page with a link to a <a href="/wiki/first-wiki/new_page_form?title=Pending+Page" class="new-page">Pending Page</a>
</p>
EOF

    chomp $html;

    is( $rev1->content_as_html( user => $user ),
        $html, 'content as html - most recent revision' );

    $page->add_revision(
        content => 'New content',
        user_id => $user->user_id(),
    );

    $rev1->_clear_page();

    is( $rev1->content_as_html( user => $user ),
        $html, 'content as html - older revision' );
}

{
    my $content1 = <<'EOF';
This is a block.

And another block.

Last block here.
EOF

    my $page = Milki::Schema::Page->insert_with_content(
        title   => 'Diff Testing',
        content => $content1,
        user_id => $user->user_id(),
        wiki_id => $wiki->wiki_id(),
    );

    my $rev1 = $page->most_recent_revision();

    my $content2 = <<'EOF';
This is a block.

And another block.
EOF

    my $rev2 = $page->add_revision(
        content => $content2,
        user_id => $user->user_id(),
    );

    my $diff
        = Milki::Schema::PageRevision->Diff( rev1 => $rev1, rev2 => $rev2 );

    is_deeply(
        $diff,
        [
            ['u', 'This is a block.',   'This is a block.'],
            ['u', 'And another block.', 'And another block.'],
            ['-', 'Last block here.',   q{}],
        ],
        'diff for two revisions, removed one block'
    );

    my $content3 = <<'EOF';
This is a block.

And another block.

New block!
EOF

    my $rev3 = $page->add_revision(
        content => $content3,
        user_id => $user->user_id(),
    );

    $diff = Milki::Schema::PageRevision->Diff( rev1 => $rev1, rev2 => $rev3 );

    is_deeply(
        $diff,
        [
            ['u', 'This is a block.',   'This is a block.'],
            ['u', 'And another block.', 'And another block.'],
            ['c', 'Last block here.',   'New block!'],
        ],
        'diff for two revisions, added a block and removed a block (looks like a change)'
    );
}

done_testing();
