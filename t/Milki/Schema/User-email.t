use strict;
use warnings;

use Test::Exception;
use Test::More;

use lib 't/lib';

use Milki::Test::Email qw( clear_emails test_email );
use Milki::Test::RealSchema;
use Milki::Schema::User;
use Milki::Schema::Wiki;

my $user1 = Milki::Schema::User->insert(
    display_name  => 'Joe Smith',
    email_address => 'joe@example.com',
    password      => 'foo',
    user          => Milki::Schema::User->SystemUser(),
);

my $user2 = Milki::Schema::User->insert(
    display_name  => 'Bjork',
    email_address => 'bjork@example.com',
    password      => 'foo',
    user          => Milki::Schema::User->SystemUser(),
);

my $wiki = Milki::Schema::Wiki->new( title => 'First Wiki' );

$user1->send_invitation_email( wiki => $wiki, sender => $user2, );

test_email(
    {
        From => q{"Bjork" <bjork@example.com>},
        To   => q{"Joe Smith" <joe@example.com>},
        Subject =>
            qr{^\QYou have been invited to join the First Wiki wiki at \E.+},
    },
    qr{<p>\s+
       \QYou have been invited to join the First Wiki wiki.\E
       \s+
       \QSince you already have a user account at \E\S+?\Q, you can <a href="http://\E\S+?\Q/wiki/first-wiki">visit the wiki right now</a>.\E
       \s+</p>
       .+?
       <p>\s+
       \QSent by Bjork\E
       \s+</p>
      }xs,
    qr{\QYou have been invited to join the First Wiki wiki. Since you already have\E
       \s+
       \Qa user account at \E\S+?\Q, you can visit the wiki right\E
       \s+
       \Qnow (http://\E\S+?\Q/wiki/first-wiki).\E
       \s+
       \QSent by Bjork\E
      }xs,
);

clear_emails();

my $user3 = Milki::Schema::User->insert(
    display_name        => 'Colin',
    email_address       => 'colin@example.com',
    password            => 'foo',
    requires_activation => 1,
    user                => Milki::Schema::User->SystemUser(),
);

$user3->send_activation_email( sender => Milki::Schema::User->SystemUser() );

test_email(
    {
        From    => qr{\Q"System User" <silki-system-user@\E.+?\Q>},
        To      => q{"Colin" <colin@example.com>},
        Subject => qr{^\QActivate your user account on the \E\S+\Q server},
    },
    qr{<p>\s+
       \QYou have created a user account on the \E\S+\Q server. You must <a href="http://\E\S+?/user/\d+/activation/.+?\Q">activate your user account</a> before you can log in.\E
       \s+</p>
       \s+
       \Q</body>\E
      }xs,
    qr{\QYou have created a user account on the \E\S+\Q server.\E\s+\QYou\E
       \s+
       \Qmust activate your user account (http://\E\S+?\)
       \s+
       \Qbefore you can log in.\E
       \s+$
      }xs,
);

clear_emails();

$user3->send_activation_email( wiki => $wiki, sender => $user2, );

test_email(
    {
        From => q{"Bjork" <bjork@example.com>},
        To   => q{"Colin" <colin@example.com>},
        Subject =>
            qr{^\QYou have been invited to join the First Wiki wiki at \E.+},
    },
    qr{<p>\s+
       \QYou have been invited to join the First Wiki wiki.\E
       \s+
       \QOnce you <a href="http://\E\S+?/user/\d+/activation/.+?\Q">activate your user account</a>, you will be a member of the wiki.\E
       \s+</p>
       .+?
       <p>\s+
       \QSent by Bjork\E
       \s+</p>
      }xs,
    qr{\QYou have been invited to join the First Wiki wiki. Once you activate your\E
       \s+
       \Quser account (http://\E\S+?\),
       \s+
       \Qyou will be a member of the wiki.\E
       \s+
       \QSent by Bjork\E
      }xs,
);

throws_ok(
    sub {
        $user3->send_invitation_email( sender => $user2, );
    },
    qr/\QCannot send an invitation email without a wiki./,
    'cannot send an invitation email without a wiki'
);

done_testing();
