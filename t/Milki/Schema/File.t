use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Milki::Test::RealSchema;

use DateTime;
use DateTime::Format::Pg;
use File::Slurp qw( read_file );
use Milki::Schema::File;
use Milki::Schema::User;
use Milki::Schema::Wiki;

my $wiki = Milki::Schema::Wiki->new( short_name => 'first-wiki' );
my $user = Milki::Schema::User->GuestUser();

{
    my $text = 'text in a file';
    my $file = Milki::Schema::File->insert(
        filename  => 'test.txt',
        mime_type => 'text/plain',
        file_size => length $text,
        contents  => $text,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    is( $file->mime_type_description_for_lang('en'),
        'Plain Text', 'english lang mime type description' );

    is(
        $file->mime_type_description_for_lang('it'),
        'Testo semplice',
        'italian lang mime type description'
    );

    is( $file->mime_type_description_for_lang('foo'),
        'Plain Text', 'mime type description falls back to default lang' );

    ok( !$file->is_browser_displayable_image(),
        'file is not an image that can be displayed in a browser' );

    ok( $file->is_displayable_in_browser(), 'file is displayable in browser' );

    is( $file->thumbnail_file(),
        undef,
        'no thumbnail file unless file is a browser displayable image' );

    my $path = $file->file_on_disk();
    is( read_file( $path->stringify() ),
        $file->contents(), "contents of file on disk" );

    $file->update( contents => 'new file content' );

    $file->_clear_file_on_disk();
    $path = $file->file_on_disk();
    isnt(
        read_file( $path->stringify() ),
        $file->contents(),
        "contents of file on disk are not updated unless known to be out of date"
    );

    my $creation = DateTime->now()->add( days => 2 );
    $file->update(
        creation_datetime => DateTime::Format::Pg->format_datetime($creation)
    );

    $file->_clear_file_on_disk();
    $path = $file->file_on_disk();
    is( read_file( $path->stringify() ),
        $file->contents(),
        "contents of file on disk are updated if out of date" );
}

{
    my $text = 'foobar';

    throws_ok {
        Milki::Schema::File->insert(
            filename  => 'test.txt',
            mime_type => 'text/plain',
            file_size => length $text,
            contents  => $text,
            user_id   => $user->user_id(),
            wiki_id   => $wiki->wiki_id(),
        );
    }
    qr/already in use/, 'cannot insert two files of the same name in a wiki';

    my $wiki2 = Milki::Schema::Wiki->new( short_name => 'second-wiki' );
    lives_ok {
        Milki::Schema::File->insert(
            filename  => 'test.txt',
            mime_type => 'text/plain',
            file_size => length $text,
            contents  => $text,
            user_id   => $user->user_id(),
            wiki_id   => $wiki2->wiki_id(),
        );
    }
    'can insert two files of the same name in different wikis';
}

{
    my $tiff = read_file('t/share/data/test.tif');
    my $file = Milki::Schema::File->insert(
        filename  => 'test.tif',
        mime_type => 'image/tiff',
        file_size => length $tiff,
        contents  => $tiff,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    ok( !$file->is_browser_displayable_image(),
        'file is not an image that can be displayed in a browser' );

    ok(
        !$file->is_displayable_in_browser(),
        'file is not displayable in browser'
    );

    is( $file->thumbnail_file(),
        undef,
        'no thumbnail file unless file is a browser displayable image' );
}

{
    my $jpg  = read_file('t/share/data/test.jpg');
    my $file = Milki::Schema::File->insert(
        filename  => 'test.jpg',
        mime_type => 'image/jpeg',
        file_size => length $jpg,
        contents  => $jpg,
        user_id   => $user->user_id(),
        wiki_id   => $wiki->wiki_id(),
    );

    ok( $file->is_browser_displayable_image(),
        'file is an image that can be displayed in a browser' );

    ok( $file->is_displayable_in_browser(), 'file is displayable in browser' );

    my $thumbnail_file = $file->thumbnail_file();
    ok( -f $thumbnail_file, 'wrote a thumbnail file' );
}

done_testing();
