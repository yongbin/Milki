use strict;
use warnings;

use Test::Most;

use autodie;
use Cwd qw( abs_path );
use File::Basename qw( dirname );
use File::HomeDir;
use File::Slurp qw( read_file );
use File::Temp qw( tempdir );
use Path::Class qw( dir );
use Milki::Config;

my $dir = tempdir( CLEANUP => 1 );

$ENV{HARNESS_ACTIVE}       = 0;
$ENV{MILKI_CONFIG_TESTING} = 1;

{
    my $config = Milki::Config->instance();

    is_deeply( $config->_build_config_hash(),
        {}, 'config hash is empty by default' );
}

{
    my $config = Milki::Config->instance();

    is( $config->_build_secret, 'a big secret',
        'secret has a basic default in dev environment' );
}

{
    local $ENV{MILKI_CONFIG} = '/path/to/nonexistent/file.conf';

    my $config = Milki::Config->instance();

    $config->_clear_config_file();

    throws_ok(
        sub { $config->_build_config_hash() },
        qr/\QNonexistent config file in MILKI_CONFIG env var/,
        'MILKI_CONFIG pointing to bad file throws an error'
    );
}

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/milki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[Milki]
secret = foobar
EOF
    close $fh;

    my $config = Milki::Config->instance();

    {
        local $ENV{MILKI_CONFIG} = $file;

        $config->_clear_config_file();

        is_deeply(
            $config->_build_config_hash(),
            { Milki => { secret => 'foobar' }, },
            'config hash uses data from file in MILKI_CONFIG'
        );
    }

    open $fh, '>', $file;
    print {$fh} <<'EOF';
[Milki]
is_production = 1
EOF
    close $fh;

    {
        local $ENV{MILKI_CONFIG} = $file;

        $config->_clear_config_file();

        throws_ok(
            sub { $config->_build_config_hash() },
            qr/\QYou must supply a value for [Milki] - secret when running Milki in production/,
            'If is_production is true in config, there must be a secret defined'
        );
    }

    open $fh, '>', $file;
    print {$fh} <<'EOF';
[Milki]
is_production = 1
secret = foobar
EOF
    close $fh;

    {
        local $ENV{MILKI_CONFIG} = $file;

        $config->_clear_config_file();

        is_deeply(
            $config->_build_config_hash(),
            { Milki => { secret => 'foobar', is_production => 1, }, },
            'config hash with is_production true and a secret defined'
        );
    }
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my @base_imports = qw(
        AuthenCookie
        +Milki::Plugin::ErrorHandling
        Session::AsObject
        Session::State::URI
        +Milki::Plugin::Session::Store::Milki
        RedirectAndDetach
        SubRequest
        Unicode
    );

    ok( $config->serve_static_files(), 'by default we serve static files' );

    is_deeply(
        $config->_build_catalyst_imports(),
        [@base_imports, 'Static::Simple', 'StackTrace'],
        'catalyst imports by default in dev setting'
    );

    Milki::Config->_clear_instance();

    $config = Milki::Config->instance();

    $config->_set_is_production(1);

    ok( !$config->serve_static_files(),
        'does not serve static files in production' );

    is_deeply( $config->_build_catalyst_imports(),
        [@base_imports], 'catalyst imports by default in production setting' );

    Milki::Config->_clear_instance();

    $config = Milki::Config->instance();

    $config->_set_is_production(0);

    $config->_set_is_profiling(1);

    ok( !$config->serve_static_files(),
        'does not serve static files when profiling' );

    is_deeply( $config->_build_catalyst_imports(),
        [@base_imports], 'catalyst imports by default in profiling setting' );

    Milki::Config->_clear_instance();

    $config = Milki::Config->instance();

    $config->_set_is_profiling(0);

    {
        local $ENV{MOD_PERL} = 1;

        ok( !$config->serve_static_files(),
            'does not serve static files under mod_perl' );

        is_deeply(
            $config->_build_catalyst_imports(),
            [@base_imports, 'StackTrace'],
            'catalyst imports by default under mod_perl'
        );
    }
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my @roles = qw(
        Milki::AppRole::Domain
        Milki::AppRole::RedirectWithError
        Milki::AppRole::Tabs
        Milki::AppRole::User
    );

    is_deeply( $config->_build_catalyst_roles(), \@roles, 'catalyst roles' );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    is( $config->_build_is_profiling(), 0, 'is_profiling defaults to false' );

    local $INC{'Devel/NYTProf.pm'} = 1;

    is( $config->_build_is_profiling(),
        1, 'is_profiling defaults is true if Devel::NYTProf is loaded' );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    is(
        $config->_build_var_lib_dir(),
        $home_dir->subdir( '.milki', 'var', 'lib' ),
        'var lib dir defaults to $HOME/.milki/var/lib'
    );

    is(
        $config->_build_share_dir(),
        dir( dirname( abs_path($0) ), '..', '..', 'share' )->resolve(),
        'share dir defaults to $CHECKOUT/share'
    );

    is(
        $config->_build_etc_dir(),
        $home_dir->subdir( '.milki', 'etc' ),
        'etc dir defaults to $HOME/.milki/etc'
    );

    is(
        $config->_build_cache_dir(),
        $home_dir->subdir( '.milki', 'cache' ),
        'cache dir defaults to $HOME/.milki/cache'
    );

    is(
        $config->_build_files_dir(),
        $home_dir->subdir( '.milki', 'cache', 'files' ),
        'files dir defaults to $HOME/.milki/cache/files'
    );

    is(
        $config->_build_thumbnails_dir(),
        $home_dir->subdir( '.milki', 'cache', 'thumbnails' ),
        'thumbnails dir defaults to $HOME/.milki/cache/thumbnails'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    $config->_set_is_production(1);

    no warnings 'redefine';
    local *Milki::Config::_ensure_dir = sub {return};

    is( $config->_build_var_lib_dir(),
        '/var/lib/milki',
        'var lib dir defaults to /var/lib/milki in production' );

    my $share_dir = dir( dir( $INC{'Milki/Config.pm'} )->parent(),
        'auto', 'share', 'dist', 'Milki' )->absolute()->cleanup();

    is( $config->_build_share_dir(),
        $share_dir,
        'share dir defaults to /usr/local/share/milki in production' );

    is( $config->_build_etc_dir(),
        '/etc/milki', 'etc dir defaults to /etc/milki in production' );

    is( $config->_build_cache_dir(),
        '/var/cache/milki',
        'cache dir defaults to /var/cache/milki in production' );

    is( $config->_build_files_dir(),
        '/var/cache/milki/files',
        'files dir defaults to /var/cache/milki/files in production' );

    is( $config->_build_thumbnails_dir(), '/var/cache/milki/thumbnails',
        'thumbnails dir defaults to /var/cache/milki/thumbnails in production'
    );
}

Milki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/milki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[dirs]
var_lib = /foo/var/lib
share   = /foo/share
etc     = /foo/etc
cache   = /foo/cache
EOF
    close $fh;

    no warnings 'redefine';
    local *Milki::Config::_ensure_dir = sub {return};

    {
        local $ENV{MILKI_CONFIG} = $file;

        my $config = Milki::Config->instance();

        is( $config->_build_var_lib_dir(),
            dir('/foo/var/lib'),
            'var lib dir defaults gets /foo/var/lib from file' );

        is( $config->_build_share_dir(),
            dir('/foo/share'),
            'var lib dir defaults gets /foo/share from file' );

        is( $config->_build_etc_dir(),
            dir('/foo/etc'), 'var lib dir defaults gets /foo/etc from file' );

        is( $config->_build_cache_dir(),
            dir('/foo/cache'),
            'var lib dir defaults gets /foo/cache from file' );
    }
}


Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my $cat = $config->_build_catalyst_config();

    is( $cat->{default_view}, 'Mason',
        'Catalyst config - default_view = Mason',
    );

    is_deeply(
        $cat->{'Plugin::Session'},
        {
            expires          => 300,
            dbi_table        => q{"Session"},
            dbi_dbh          => 'Milki::Plugin::Session::Store::Milki',
            object_class     => 'Milki::Web::Session',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },
        'Catalyst config - Plugin::Session'
    );

    is_deeply(
        $cat->{authen_cookie},
        {
            name       => 'Milki-user',
            path       => '/',
            mac_secret => $config->secret(),
        },
        'Catalyst config - authen_cookie'
    );

    is( $cat->{root}, $config->share_dir(),
        'Catalyst config - root is share_dir',
    );

    is_deeply(
        $cat->{static},
        {
            dirs         => [qw( files images js css static w3c ckeditor )],
            include_path => [
                $config->cache_dir()->stringify(),
                $config->var_lib_dir()->stringify(),
                $config->share_dir()->stringify(),
            ],
            debug => 1,
        },
        'Catalyst config - static in dev environment'
    );

    $config->_set_is_production(1);

    $cat = $config->_build_catalyst_config();

    ok( !$cat->{static}, 'no static config for prod environment' );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    is_deeply(
        $config->_build_dbi_config(),
        { dsn => 'dbi:Pg:dbname=Milki', username => q{}, password => q{}, },
        'default dbi config'
    );
}

Milki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );
    my $file = "$dir/milki.conf";
    open my $fh, '>', $file;
    print {$fh} <<'EOF';
[database]
name = Foo
host = example.com
port = 9876
username = user
password = pass
EOF
    close $fh;

    local $ENV{MILKI_CONFIG} = $file;

    my $config = Milki::Config->instance();

    is_deeply(
        $config->_build_dbi_config(),
        {
            dsn      => 'dbi:Pg:dbname=Foo;host=example.com;port=9876',
            username => 'user',
            password => 'pass',
        },
        'dbi config from file'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    my $share_dir = $config->share_dir();

    is_deeply(
        $config->_build_mason_config(),
        {
            comp_root => $share_dir->subdir('mason'),
            data_dir => $home_dir->subdir( '.milki', 'cache', 'mason', 'web' ),
            error_mode           => 'fatal',
            in_package           => 'Milki::Mason::Web',
            use_match            => 0,
            default_escape_flags => 'h',
        },
        'default mason config'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    no warnings 'redefine';
    local *Milki::Config::_ensure_dir = sub {return};

    $config->_set_is_production(1);

    my $share_dir = $config->share_dir();

    is_deeply(
        $config->_build_mason_config(),
        {
            comp_root                => $share_dir->subdir('mason'),
            data_dir                 => '/var/cache/milki/mason/web',
            error_mode               => 'fatal',
            in_package               => 'Milki::Mason::Web',
            use_match                => 0,
            default_escape_flags     => 'h',
            static_source            => 1,
            static_source_touch_file => '/etc/Milki/mason-touch',
        },
        'mason config in production'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my $home_dir = dir( File::HomeDir->my_home() );

    my $share_dir = $config->share_dir();

    is_deeply(
        $config->_build_mason_config_for_email(),
        {
            comp_root => $share_dir->subdir('email-templates'),
            data_dir =>
                $home_dir->subdir( '.milki', 'cache', 'mason', 'email' ),
            error_mode => 'fatal',
            in_package => 'Milki::Mason::Email',
        },
        'default mason config for email'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    no warnings 'redefine';
    local *Milki::Config::_ensure_dir = sub {return};

    $config->_set_is_production(1);

    my $share_dir = $config->share_dir();

    is_deeply(
        $config->_build_mason_config_for_email(),
        {
            comp_root                => $share_dir->subdir('email-templates'),
            data_dir                 => '/var/cache/milki/mason/email',
            error_mode               => 'fatal',
            in_package               => 'Milki::Mason::Email',
            static_source            => 1,
            static_source_touch_file => '/etc/Milki/mason-touch',
        },
        'mason config for email in production'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    is( $config->static_path_prefix(),
        q{}, 'in dev environment, no static path prefix' );
}

Milki::Config->_clear_instance();

{
    my $dir     = tempdir( CLEANUP => 1 );
    my $etc_dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/milki.conf";
    open my $fh, '>', $file;
    print {$fh} <<"EOF";
[dirs]
etc = $etc_dir
EOF
    close $fh;

    local $ENV{MILKI_CONFIG} = $file;

    my $config = Milki::Config->instance();

    $config->_set_is_production(1);

    my $version = $Milki::Config::VERSION || 'wc';
    is(
        $config->static_path_prefix(),
        q{/} . $version,
        'in prod environment, static path prefix includes a version'
    );
}

Milki::Config->_clear_instance();

{
    my $dir     = tempdir( CLEANUP => 1 );
    my $etc_dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/milki.conf";
    open my $fh, '>', $file;
    print {$fh} <<"EOF";
[dirs]
etc = $etc_dir
EOF
    close $fh;

    local $ENV{MILKI_CONFIG} = $file;

    my $config = Milki::Config->instance();

    $config->_set_is_production(1);

    $config->_set_path_prefix('/foo');

    my $version = $Milki::Config::VERSION || 'wc';

    is( $config->static_path_prefix(), qq{/foo/$version},
        'in prod environment, static path prefix includes revision number and general prefix'
    );
}

Milki::Config->_clear_instance();

{
    my $config = Milki::Config->instance();

    my $dir = tempdir( CLEANUP => 1 );

    my $new_dir = dir($dir)->subdir('foo');

    $config->_ensure_dir($new_dir);

    ok( -d $new_dir, '_ensure_dir makes a new directory if needed' );
}

Silki::Config->_clear_instance();

{
    my $dir = tempdir( CLEANUP => 1 );

    my $file = "$dir/silki.conf";

    my $config = Silki::Config->instance();

    $config->write_config_file(
        file   => $file,
        values => {
            'database/name'     => 'Foo',
            'database/username' => 'fooer',
            'dirs/share'        => '/path/to/share',
            'antispam/key'      => 'abcdef',
        },
    );

    my $content = read_file($file);
    like(
        $content,
        qr/\Q; Config file generated by Silki version \E.+/,
        'generated config file includes Silki version'
    );

    like(
        $content,
        qr/\Q; static =/,
        'generated config file does not set static'
    );

    like(
        $content,
        qr/\Qname = Foo/,
        'generated config file includes explicit set value for database name'
    );

    like(
        $content,
        qr/\Qusername = fooer/,
        'generated config file includes explicit set value for database username'
    );

    like(
        $content,
        qr/\[database\].+?name = Foo.+?username = fooer/s,
        'generated config file keys are in order defined by meta description'
    );

    like(
        $content,
        qr/\[Silki\].+?\[antispam\].+?\[database\]/s,
        'section order is alphabetical, except that first section is Silki'
    );
}

done_testing();
