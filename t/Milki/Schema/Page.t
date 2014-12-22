use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Milki::Test::RealSchema;

use DateTime;
use DateTime::Format::Pg;
use Milki::Schema::Domain;
use Milki::Schema::File;
use Milki::Schema::Page;
use Milki::Schema::PendingPageLink;
use Milki::Schema::Wiki;

my $dbh  = Milki::Schema->DBIManager()->default_source()->dbh();
my $wiki = Milki::Schema::Wiki->new( short_name => 'first-wiki' );
my $user = Milki::Schema::User->GuestUser();

{
    my $page = Milki::Schema::Page->insert_with_content(
        title   => 'Some Page',
        content => 'This is a page with a link to a ((Pending Page))',
        user_id => $user->user_id(),
        wiki_id => $wiki->wiki_id(),
    );

    is( $page->uri_path(), 'Some_Page',
        'title is converted to uri_path on page insert' );
    is( $page->uri(), '/wiki/first-wiki/page/Some_Page', 'uri() for page' );

    is_deeply(
        $dbh->selectall_arrayref(
            q{SELECT * FROM "PendingPageLink" WHERE from_page_id = ?},
            { Slice => {} },
            $page->page_id(),
        ),
        [
            {
                from_page_id  => $page->page_id(),
                to_wiki_id    => $wiki->wiki_id(),
                to_page_title => 'Pending Page',
            },
        ],
        'creating a page inserts PendingPageLink rows as needed',
    );

    is_deeply(
        $dbh->selectcol_arrayref(
            q{SELECT COUNT(*) FROM "PageRevision" where page_id = ? }, {},
            $page->page_id(),
        ),
        [1],
        'calling insert_with_content creates a page and a page revision',
    );

    my $revision = $page->most_recent_revision();
    is( $revision->revision_number(),
        1, 'most_recent_revision returns revision 1' );
}

{
    my $page = Milki::Schema::Page->new(
        title   => 'Front Page',
        wiki_id => $wiki->wiki_id(),
    );

    ok( $page->is_front_page(),
        'is_front_page is true for page where title is Front Page' );
}

{
    my $page = Milki::Schema::Page->insert_with_content(
        title   => 'Pending Page',
        content => 'Resolves a pending page link',
        user_id => $user->user_id(),
        wiki_id => $wiki->wiki_id(),
    );

    is_deeply(
        $dbh->selectall_arrayref(
            q{SELECT * FROM "PendingPageLink" WHERE to_page_title = ?},
            { Slice => {} },
            'Pending Page',
        ),
        [],
        'creating a page resolves pending page links',
    );

    my $revision = $page->most_recent_revision();
    is( $revision->revision_number(),
        1, 'most_recent_revision returns revision 1' );

    is( $page->revision_count(), 1, 'revision_count is 1' );

    $page->add_revision(
        content => 'New Revision',
        user_id => $user->user_id(),
    );

    is_deeply(
        $dbh->selectcol_arrayref(
            q{SELECT COUNT(*) FROM "PageRevision" where page_id = ? }, {},
            $page->page_id(),
        ),
        [2],
        'calling add_revision creates a new page',
    );

    $revision = $page->most_recent_revision();
    is( $revision->revision_number(),
        2, 'most_recent_revision returns revision 2' );

    is( $page->revision_count(), 2, 'revision_count is 2' );

    my @revisions = $page->revisions()->all();
    is_deeply( [map { $_->revision_number() } @revisions],
        [2, 1],
        'page has two revisions, which are returned with most recent first' );

    my $first_rev = $page->first_revision();
    is( $first_rev->revision_number(),
        1, 'first_revision returns the right object' );

    my $text  = "This is some plain text.\n";
    my $file1 = Milki::Schema::File->insert(
        filename  => 'test1.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    $page->add_file($file1);

    $revision = $page->most_recent_revision();
    is( $revision->revision_number(),
        3, 'adding a file to a page creates a new revision' );

    my $link = '{{file:' . $file1->filename() . '}}';
    like( $revision->content(), qr/\Q$link/,
        'new revision has a link to the added file' );

    is( $page->revision_count(), 3, 'revision_count is 3' );

    $text = "This is some more plain text.\n";
    my $file2 = Milki::Schema::File->insert(
        filename  => 'test2.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    $page->add_file($file2);

    # Creating this so that we know $page->files() doesn't just return all the
    # files in the wiki or some other wrong result.
    $text = "This is even more plain text.\n";
    my $file3 = Milki::Schema::File->insert(
        filename  => 'test3.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    is( $page->file_count(), 2, 'file_count is 2' );
    is_deeply(
        [sort map { $_->filename() } $page->files()->all()],
        [qw( test1.txt test2.txt )],
        'files returns the right two files',
    );

    ok( !$page->is_front_page(), 'page is not the front page' );

    is( $page->incoming_link_count(), 1, 'page has one incoming link' );
    my @links = $page->incoming_links()->all();
    is( $links[0]->title(), 'Some Page', 'Some Page links to Pending Page' );
}

{
    throws_ok {
        Milki::Schema::Page->insert_with_content(
            title   => 'Bad title )) here',
            content => 'foo',
            user_id => $user->user_id(),
            wiki_id => $wiki->wiki_id(),
        );
    }
    qr/\Qcannot contain the characters "))"/,
        'cannot use "))" in a page title';

    throws_ok {
        Milki::Schema::Page->insert_with_content(
            title   => 'Bad title / here',
            content => 'foo',
            user_id => $user->user_id(),
            wiki_id => $wiki->wiki_id(),
        );
    }
    qr/\Qcannot contain a slash/, 'cannot use / in a page title';
}

done_testing();
