package Milki::SeedData;

use strict;
use warnings;

our $VERBOSE;

sub seed_data {
    my %p = @_;

    local $VERBOSE = $p{verbose};

    require Milki::Schema::Locale;

    Milki::Schema::Locale->CreateDefaultLocales();

    require Milki::Schema::Country;

    Milki::Schema::Country->CreateDefaultCountries();

    require Milki::Schema::TimeZone;

    Milki::Schema::TimeZone->CreateDefaultZones();

    require Milki::Schema::Domain;

    Milki::Schema::Domain->EnsureRequiredDomainsExist();

    # require Milki::Schema::User;

    # Milki::Schema::User->EnsureRequiredUsersExist();

    require Milki::Schema::Account;

    Milki::Schema::Account->EnsureRequiredAccountsExist();

    # require Milki::Schema::Role;

    # print "\n" if $VERBOSE;

    # my $admin = _make_admin_user();
    # my $regular = _make_regular_user() unless $p{production};

    # if ( $p{production} ) {
    #     _make_production_wiki($admin);
    # }
    # else {
    #     _make_first_wiki( $admin, $regular );
    #     _make_second_wiki( $admin, $regular );
    #     _make_third_wiki( $admin, $regular );
    # }
}

sub _make_admin_user {
    my $email
        = 'admin@' . Milki::Schema::Domain->DefaultDomain()->email_hostname();

    my $admin = _make_user( 'Angela D. Min', $email, 1 );

    Milki::Schema::Account->DefaultAccount()->add_admin($admin);

    return $admin;
}

sub _make_regular_user {
    my $email
        = 'joe@' . Milki::Schema::Domain->DefaultDomain()->email_hostname();

    return _make_user( 'Joe Schmoe', $email );
}

sub _make_user {
    my $name     = shift;
    my $email    = shift;
    my $is_admin = shift;

    my $pw = 'changeme';

    my $user = Milki::Schema::User->insert(
        display_name  => $name,
        email_address => $email,
        password      => $pw,
        time_zone     => 'America/Chicago',
        is_admin      => ( $is_admin ? 1 : 0 ),
        user          => Milki::Schema::User->SystemUser(),
    );

    if ($VERBOSE) {
        my $type = $is_admin ? 'an admin' : 'a regular';

        print <<"EOF";
Created $type user:

  email:    $email
  password: $pw

EOF
    }

    return $user;
}

sub _make_first_wiki {
    my $admin   = shift;
    my $regular = shift;

    my $wiki = _make_wiki( 'First Wiki', 'first-wiki' );

    $wiki->set_permissions('public');

    $wiki->add_user( user => $admin,   role => Milki::Schema::Role->Admin() );
    $wiki->add_user( user => $regular, role => Milki::Schema::Role->Member() );
}

sub _make_production_wiki {
    my $admin = shift;

    my $wiki = _make_wiki( 'My Wiki', 'my-wiki' );

    $wiki->set_permissions('private');

    $wiki->add_user( user => $admin, role => Milki::Schema::Role->Admin() );
}

sub _make_second_wiki {
    my $admin   = shift;
    my $regular = shift;

    my $wiki = _make_wiki( 'Second Wiki', 'second-wiki' );

    $wiki->set_permissions('private');

    $wiki->add_user( user => $admin,   role => Milki::Schema::Role->Admin() );
    $wiki->add_user( user => $regular, role => Milki::Schema::Role->Member() );
}

sub _make_third_wiki {
    my $admin   = shift;
    my $regular = shift;

    my $wiki = _make_wiki( 'Third Wiki', 'third-wiki' );

    $wiki->set_permissions('private');

    $wiki->add_user( user => $regular, role => Milki::Schema::Role->Member() );
}

sub _make_wiki {
    my $title = shift;
    my $name  = shift;

    require Milki::Schema::Wiki;

    my $wiki = Milki::Schema::Wiki->insert(
        title      => $title,
        short_name => $name,
        domain_id  => Milki::Schema::Domain->DefaultDomain()->domain_id(),
        user       => Milki::Schema::User->SystemUser(),
    );

    my $uri = $wiki->uri( with_host => 1 );

    if ($VERBOSE) {
        print <<"EOF";
Created a wiki:

  Title: $title
  URI:   $uri

EOF
    }

    return $wiki;
}

1;

# ABSTRACT: Seeds a fresh database with data
