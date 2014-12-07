use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Milki::Test::Email qw( clear_emails test_email );
use Milki::Test::FakeSchema;

use Cwd qw( abs_path );
use File::Temp qw( tempdir );
use Milki::Config;
use Milki::HTML::FormatText;

BEGIN {
    Milki::Config->new()->mason_config_for_email->{comp_root}
        = abs_path('t/share/mason/email');
    Milki::Config->new()->mason_config_for_email->{data_dir}
        = tempdir( CLEANUP => 1 );
}

use Milki::Email;

{

    package Milki::Schema::User;

    no warnings 'redefine';

    my $user = Milki::Schema::User->new(
        user_id        => 42,
        display_name   => 'System User',
        username       => 'system-user',
        email_address  => 'system-user@example.com',
        password       => '*disabled*',
        is_system_user => 1,
        _from_query    => 1,
    );

    sub SystemUser {$user}
}

Milki::Email::send_email(
    from            => 'foo@example.com',
    to              => 'bar@example.com',
    subject         => 'Test email',
    template        => 'test',
    template_params => { uri => 'http://example.com' },
);

my $version = $Milki::Email::VERSION || 'from working copy';
test_email(
    {
        From         => 'foo@example.com',
        To           => 'bar@example.com',
        Subject      => 'Test email',
        'Message-ID' => qr/^<.+>$/,
        'X-Sender'   => "Milki version $version",
    },
    qr{<p>
       \s+
       \QThe user can pass a <a href="http://example.com">uri</a>.\E
       \s+
       </p>}x,
    qr{\QThe user can pass a uri (http://example.com).\E},
);

clear_emails();

Milki::Email::send_email(
    from     => 'foo@example.com',
    to       => 'bar@example.com',
    subject  => 'Test email',
    template => 'test',
);

test_email(
    {}, qr{<p>
       \s+
       \QSome random content goes here.\E
       \s+
       </p>
       \s*
       \z}x, qr{\QSome random content goes here.\E\s*\z},
);

done_testing();
