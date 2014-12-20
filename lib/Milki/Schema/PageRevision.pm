package Milki::Schema::PageRevision;

use strict;
use warnings;
use namespace::autoclean;

use Algorithm::Diff qw( sdiff );
use List::AllUtils qw( all any );
use Markdent::CapturedEvents;
use Markdent::Handler::CaptureEvents;
use Markdent::Handler::HTMLFilter;
use Markdent::Handler::Multiplexer;
use Markdent::Parser;
use String::Diff qw( diff );
use Milki::Config;
use Milki::Markdent::Dialect::Milki::BlockParser;
use Milki::Markdent::Dialect::Milki::SpanParser;
use Milki::Markdent::Handler::ExtractWikiLinks;
use Milki::Markdent::Handler::HTMLStream;
use Milki::Schema;
use Milki::Schema::Page;
use Milki::Schema::PageLink;
use Milki::Schema::PageFileLink;
use Milki::Schema::PendingPageLink;
use Milki::Types qw( Bool );
use Storable qw( nfreeze thaw );

use Fey::ORM::Table;
use MooseX::Params::Validate qw( validated_list validated_hash );

with 'Milki::Role::Schema::URIMaker';

my $Schema = Milki::Schema->Schema();

has_policy 'Milki::Schema::Policy';

has_table( $Schema->table('PageRevision') );

has_one page => ( table => $Schema->table('Page'), handles => ['domain'], );

has_one( $Schema->table('User') );

transform content => deflate {
    return unless defined $_[1];
    $_[1] =~ s/\r\n|\r/\n/g;
    return $_[1];
};

around insert => sub {
    my $orig  = shift;
    my $class = shift;

    my $revision = $class->$orig(@_);

    $revision->_post_change();

    return $revision;
};

after update => sub {
    my $self = shift;

    $self->_post_change();
};

sub _post_change {
    my $self = shift;

    my ( $existing, $pending, $files, $capture )
        = $self->_process_extracted_links();

    my $delete_existing = Milki::Schema->SQLFactoryClass()->new_delete();
    $delete_existing->delete()->from( $Schema->table('PageLink') )
        ->where( $Schema->table('PageLink')->column('from_page_id'),
        '=', $self->page_id() );

    my $delete_pending = Milki::Schema->SQLFactoryClass()->new_delete();
    $delete_pending->delete()->from( $Schema->table('PendingPageLink') )
        ->where( $Schema->table('PendingPageLink')->column('from_page_id'),
        '=', $self->page_id() );

    my $delete_files = Milki::Schema->SQLFactoryClass()->new_delete();
    $delete_files->delete()->from( $Schema->table('PageFileLink') )
        ->where( $Schema->table('PageFileLink')->column('page_id'),
        '=', $self->page_id() );

    my $update_cached_content = Milki::Schema->SQLFactoryClass()->new_update();
    $update_cached_content->update( $Schema->table('Page') )
        ->set( $Schema->table('Page')->column('cached_content') =>
            nfreeze( $capture->captured_events() ) )
        ->where( $Schema->table('Page')->column('page_id'),
        '=', $self->page_id() );

    my $dbh
        = Milki::Schema->DBIManager()->source_for_sql($delete_existing)->dbh();

    my $updates = sub {
        $dbh->do( $delete_existing->sql($dbh),
            {}, $delete_existing->bind_params() );
        $dbh->do( $delete_pending->sql($dbh),
            {}, $delete_pending->bind_params() );
        $dbh->do( $delete_files->sql($dbh), {}, $delete_files->bind_params() );

        my $sth  = $dbh->prepare( $update_cached_content->sql($dbh) );
        my @bind = $update_cached_content->bind_params();
        $sth->bind_param( 1, $bind[0], { pg_type => DBD::Pg::PG_BYTEA() } );
        $sth->bind_param( 2, $bind[1] );
        $sth->execute();

        Milki::Schema::PageLink->insert_many( @{$existing} ) if @{$existing};
        Milki::Schema::PendingPageLink->insert_many( @{$pending} )
            if @{$pending};
        Milki::Schema::PageFileLink->insert_many( @{$files} ) if @{$files};
    };

    Milki::Schema->RunInTransaction($updates);
}

sub _process_extracted_links {
    my $self = shift;

    my $capture = Markdent::Handler::CaptureEvents->new();
    my $linkex  = Milki::Markdent::Handler::ExtractWikiLinks->new(
        wiki => $self->page()->wiki(), );
    my $multi
        = Markdent::Handler::Multiplexer->new( handlers => [$capture, $linkex],
        );

    my $filter = Markdent::Handler::HTMLFilter->new( handler => $multi );

    my $parser = Markdent::Parser->new(
        dialect => 'Milki::Markdent::Dialect::Milki',
        handler => $filter,
    );

    $parser->parse( markdown => $self->content() );

    my $links = $linkex->links();

    my @existing = map {
        {
            from_page_id => $self->page_id(),
            to_page_id   => $links->{$_}{page}->page_id(),
        }
    } grep { $links->{$_}{page} } keys %{$links};

    my @pending = map {
        {
            from_page_id  => $self->page_id(),
            to_wiki_id    => $links->{$_}{wiki}->wiki_id(),
            to_page_title => $links->{$_}{title},
        }
    } grep { $links->{$_}{title} && !$links->{$_}{page} } keys %{$links};

    my @files = map {
        {
            page_id => $self->page_id(),
            file_id => $links->{$_}{file}->file_id(),
        }
    } grep { $links->{$_}{file} } keys %{$links};

    return \@existing, \@pending, \@files, $capture;
}

sub _base_uri_path {
    my $self = shift;

    my $page = $self->page();

    return $page->_base_uri_path() . '/revision/' . $self->revision_number();
}

sub Diff {
    my $class = shift;
    my ( $rev1, $rev2 ) = validated_list(
        \@_,
        rev1 => { isa => 'Milki::Schema::PageRevision' },
        rev2 => { isa => 'Milki::Schema::PageRevision' },
    );

    my @rev1 = map { s/^\s+|\s+$//; $_ } split /\n\n+/, $rev1->content();
    my @rev2 = map { s/^\s+|\s+$//; $_ } split /\n\n+/, $rev2->content();

    return $class->_BlockLevelDiff( \@rev1, \@rev2 );
}

sub _BlockLevelDiff {
    my $class = shift;
    my $rev1  = shift;
    my $rev2  = shift;

    return $class->_ReorderIfTotalReplacement( [sdiff( $rev1, $rev2, )] );
}

# If the two revisions have nothing in common, we reorder the diff so all the
# inserts come first and the deletes come second. This will show all new
# content first, followed by all the removed old content.
sub _ReorderIfTotalReplacement {
    my $class = shift;
    my $diff  = shift;

    return $diff if any { $_->[0] =~ /[uc]/ } @{$diff};

    return [
        ( grep { $_->[0] eq q{+} } @{$diff} ),
        ( grep { $_->[0] eq q{-} } @{$diff} ),
    ];
}

sub content_as_html {
    my $self = shift;
    my (%p) = validated_hash(
        \@_,
        user       => { isa => 'Milki::Schema::User' },
        for_editor => { isa => Bool, default => 0 },
    );

    my $page = $self->page();

    my $buffer = q{};
    open my $fh, '>', \$buffer;

    my $html = Milki::Markdent::Handler::HTMLStream->new(
        output => $fh,
        wiki   => $page->wiki(),
        %p,
    );

    if ( $self->revision_number()
        == $page->most_recent_revision()->revision_number() )
    {
        my $captured = thaw( $page->cached_content() );

        $captured->replay_events($html);
    }
    else {
        my $filter = Markdent::Handler::HTMLFilter->new( handler => $html );

        my $parser = Markdent::Parser->new(
            dialect => 'Milki::Markdent::Dialect::Milki',
            handler => $filter,
        );

        $parser->parse( markdown => $self->content() );
    }

    return $buffer;
}

__PACKAGE__->meta()->make_immutable();

1;

# ABSTRACT: Represents a page revision
