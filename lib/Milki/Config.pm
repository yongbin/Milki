package Milki::Config;

use strict;
use warnings;
use namespace::autoclean;
use autodie qw( :all );

use File::HomeDir;
use File::Slurp qw( write_file );
use File::Temp qw( tempdir );
use Net::Interface;
use Path::Class;
use Milki::ConfigFile;
use Milki::Types qw( Bool Str Int ArrayRef HashRef Dir File Maybe );
use Milki::Util qw( string_is_empty );
use Socket qw( AF_INET );
use Sys::Hostname qw( hostname );
use Text::Autoformat qw( autoformat );

use MooseX::MetaDescription;
use MooseX::Params::Validate qw( validated_list );
use MooseX::Singleton;

has config_file => (
    is   => 'rw',
    isa  => 'Milki::ConfigFile',
    lazy => 1,
    default =>
        sub { Milki::ConfigFile->new( home_dir => $_[0]->_home_dir() ) },
    clearer => '_clear_config_file',
);

has _config_hash => (
    is      => 'rw',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_config_hash',
    writer  => '_set_config_hash',
    clearer => '_clear_config_hash',
);

has is_production => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Bool,
    lazy        => 1,
    builder     => '_build_is_production',
    description => {
        config_path => ['Milki', 'is_production'],
        description =>
            'A flag indicating whether or not this is a production install. This should probably be true unless you are actively developing Milki.',
        key_order => 1,
    },
    writer => '_set_is_production',
);

has max_upload_size => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'ro',
    isa     => Int,
    lazy    => 1,
    default => sub {
        $_[0]->_from_config_path('max_upload_size') || ( 10 * 1000 * 1000 );
    },
    description => {
        config_path => ['Milki', 'max_upload_size'],
        description =>
            'The maximum size of an upload in bytes. Defaults to 10 megabytes.',
        key_order => 2,
    },
);

has path_prefix => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    default     => sub { $_[0]->_from_config_path('path_prefix') || q{} },
    description => {
        config_path => ['Milki', 'path_prefix'],
        description =>
            'The URI path prefix for your Milki install. By default, this is empty. This affects URI generation and resolution.',
        key_order => 3,
    },
    writer => '_set_path_prefix',
);

has serve_static_files => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'ro',
    isa         => Bool,
    lazy        => 1,
    builder     => '_build_serve_static_files',
    description => {
        config_path => ['Milki', 'static'],
        description =>
            'If this is true, the Milki application will serve static files itself. Defaults to false when is_production is true.',
        key_order => 4,
    },
);

has secret => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    lazy        => 1,
    builder     => '_build_secret',
    description => {
        config_path => ['Milki', 'secret'],
        description =>
            'A secret used as salt for digests in some URIs and for user authentication cookies. Changing this will invalidate all existing cookies.',
        key_order => 5,
    },
    writer => '_set_secret',
);

has is_profiling => (
    is      => 'rw',
    isa     => Bool,
    lazy    => 1,
    builder => '_build_is_profiling',
    writer  => '_set_is_profiling',
);

has catalyst_imports => (
    is      => 'ro',
    isa     => ArrayRef [Str],
    lazy    => 1,
    builder => '_build_catalyst_imports',
);

has catalyst_roles => (
    is      => 'ro',
    isa     => ArrayRef [Str],
    lazy    => 1,
    builder => '_build_catalyst_roles',
);

has catalyst_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_catalyst_config',
);

has dbi_config =>
    ( is => 'ro', isa => HashRef, lazy => 1, builder => '_build_dbi_config', );

has database_name => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    default => sub { $_[0]->_from_config_path('database_name') || 'Milki' },
    description => {
        config_path => ['database', 'name'],
        description => 'The name of the database. Defaults to Milki.',
        key_order   => 1,
    },
    writer => '_set_database_name',
);

has database_username => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    default => sub { $_[0]->_from_config_path('database_username') || q{} },
    description => {
        config_path => ['database', 'username'],
        description =>
            'The username to use when connecting to the database. By default, this is empty.',
        key_order => 2,
    },
    writer => '_set_database_username',
);

has database_password => (
    traits  => ['MooseX::MetaDescription::Meta::Trait'],
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    default => sub { $_[0]->_from_config_path('database_password') || q{} },
    description => {
        config_path => ['database', 'password'],
        description =>
            'The password to use when connecting to the database. By default, this is empty.',
        key_order => 3,
    },
    writer => '_set_database_password',
);

has database_host => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('database_host') || q{} },
    description => {
        config_path => ['database', 'host'],
        description =>
            'The host to use when connecting to the database. By default, this is empty.',
        key_order => 4,
    },
    writer => '_set_database_host',
);

has database_port => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('database_port') || q{} },
    description => {
        config_path => ['database', 'port'],
        description =>
            'The port to use when connecting to the database. By default, this is empty.',
        key_order => 5,
    },
    writer => '_set_database_port',
);

has mason_config => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config',
);

has mason_config_for_email => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config_for_email',
);

has mason_config_for_help => (
    is      => 'ro',
    isa     => HashRef,
    lazy    => 1,
    builder => '_build_mason_config_for_help',
);

has _home_dir => (
    is      => 'rw',
    isa     => Dir,
    lazy    => 1,
    default => sub { dir( File::HomeDir->my_home() ) },
    writer  => '_set_home_dir',
);

has var_lib_dir =>
    ( is => 'ro', isa => Dir, lazy => 1, builder => '_build_var_lib_dir', );

has share_dir => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Dir,
    lazy        => 1,
    builder     => '_build_share_dir',
    description => {
        config_path => ['dirs', 'share'],
        description =>
            'The directory where share files are located. By default, these are installed in the Perl module directory tree, but you might want to change this to something like /usr/local/share/Milki.',
        key_order => 1,
    },
    writer => '_set_share_dir',
    coerce => 1,
);

has _etc_dir => (
    is      => 'rw',
    isa     => Dir,
    lazy    => 1,
    default => sub {
        $_[0]->config_file()->file()
            ? $_[0]->config_file()->file()->dir()
            : '/etc/Milki';
    },
    writer => '_set_etc_dir',
    coerce => 1,
);

has cache_dir => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Dir,
    lazy        => 1,
    builder     => '_build_cache_dir',
    description => {
        config_path => ['dirs', 'cache'],
        description =>
            'The directory where generated files are stored. Defaults to /var/cache/Milki.',
        key_order => 2,
    },
    writer => '_set_cache_dir',
    coerce => 1,
);

has files_dir =>
    ( is => 'ro', isa => Dir, lazy => 1, builder => '_build_files_dir', );

has small_image_dir => (
    is      => 'ro',
    isa     => Dir,
    lazy    => 1,
    builder => '_build_small_image_dir',
);

has thumbnails_dir =>
    ( is => 'ro', isa => Dir, lazy => 1, builder => '_build_thumbnails_dir', );

has static_path_prefix => (
    is      => 'rw',
    isa     => Str,
    lazy    => 1,
    builder => '_build_static_path_prefix',
    writer  => '_set_static_path_prefix',
    clearer => '_clear_static_path_prefix',
);

has system_hostname => (
    is      => 'ro',
    isa     => Str,
    lazy    => 1,
    builder => '_build_system_hostname',
);

has antispam_server => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('antispam_server') || q{} },
    description => {
        config_path => ['antispam', 'server'],
        description =>
            'The antispam server to use. This defaults to api.antispam.typepad.com.',
        key_order => 1,
    },
    writer => '_set_antispam_server',
);

has antispam_key => (
    traits      => ['MooseX::MetaDescription::Meta::Trait'],
    is          => 'rw',
    isa         => Str,
    lazy        => 1,
    default     => sub { $_[0]->_from_config_path('antispam_key') || q{} },
    description => {
        config_path => ['antispam', 'key'],
        description =>
            'A key for your antispam server. If this is empty, Milki will not be able to check for spam links.',
        key_order => 2,
    },
    writer => '_set_antispam_key',
);

sub _build_config_hash {
    my $self = shift;

    my $hash = $self->config_file()->raw_data();

    # Can't call $self->is_production() or else we get a loop
    if ( $hash->{Milki} && $hash->{Milki}{is_production} ) {
        die
            'You must supply a value for [Milki] - secret when running Milki in production'
            if string_is_empty( $hash->{Milki}{secret} );
    }

    return $hash;
}

sub _from_config_path {
    my $self      = shift;
    my $attr_name = shift;

    my $attr = $self->meta()->get_attribute($attr_name)
        or die "Bad attribute name: $attr_name";

    $attr->can('description')
        or die "Attribute $attr_name has no meta-description";

    my $path = $attr->description()->{config_path}
        or die
        "Attribute $attr_name has no config path in the meta-description";

    my $hash = $self->_config_hash();

    for my $key ( @{$path} ) {
        $hash = $hash->{$key};

        return if string_is_empty($hash);
    }

    if ( ref $hash ) {
        die "Config path @{$path} did not resolve to a non-reference value";
    }

    return $hash;
}

sub _build_is_production {
    my $self = shift;

    return 0 if $ENV{HARNESS_ACTIVE};

    return $self->_from_config_path('is_production') || 0;
}

{
    my @StandardImports = qw(
        AuthenCookie
        +Milki::Plugin::ErrorHandling
        Session::AsObject
        Session::State::URI
        +Milki::Plugin::Session::Store::Milki
        RedirectAndDetach
        SubRequest
        Unicode
    );

    sub _build_catalyst_imports {
        my $self = shift;

        my @imports = @StandardImports;
        push @imports, 'Static::Simple' if $self->serve_static_files();

        push @imports, 'StackTrace'
            unless $self->is_production() || $self->is_profiling();

        return \@imports;
    }
}

sub _build_serve_static_files {
    my $self = shift;

    if ( exists $self->_config_hash()->{Milki}{static} ) {
        return $self->_config_hash()->{Milki}{static};
    }

    return !( $ENV{MOD_PERL}
        || $self->is_production()
        || $self->is_profiling() );
}

{
    my @StandardRoles = qw(
        Milki::AppRole::Domain
        Milki::AppRole::RedirectWithError
        Milki::AppRole::Tabs
        Milki::AppRole::User
    );

    sub _build_catalyst_roles {
        return \@StandardRoles;
    }
}

{
    my @Profilers = qw(
        Devel/DProf.pm
        Devel/FastProf.pm
        Devel/NYTProf.pm
        Devel/Profile.pm
        Devel/Profiler.pm
        Devel/SmallProf.pm
    );

    sub _build_is_profiling {
        return 1 if grep { $INC{$_} } @Profilers;
        return 0;
    }
}

sub _build_var_lib_dir {
    my $self = shift;

    return $self->_dir( ['var', 'lib'], '/var/lib/milki', );
}

sub _build_share_dir {
    my $self = shift;

    # I'd like to use File::ShareDir, but it blows up if the directory doesn't
    # exist, which isn't very fucking helpful. This is equivalent to
    # dist_dir('Milki')
    my $share_dir = dir( dir( $INC{'Milki/Config.pm'} )->parent(),
        'auto', 'share', 'dist', 'Milki' )->absolute()->cleanup();

    return $self->_dir( ['share'], $share_dir, dir('share')->absolute(), );
}

sub _build_etc_dir {
    my $self = shift;

    return $self->_dir( ['etc'], '/etc/milki', );
}

sub _build_cache_dir {
    my $self = shift;

    return $self->_dir( ['cache'], '/var/cache/milki', );
}

sub _build_files_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $files_dir = $cache->subdir('files');

    $self->_ensure_dir($files_dir);

    return $files_dir;
}

sub _build_small_image_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $small_image_dir = $cache->subdir('small-image');

    $self->_ensure_dir($small_image_dir);

    return $small_image_dir;
}

sub _build_thumbnails_dir {
    my $self = shift;

    my $cache = $self->cache_dir();

    my $thumbnails_dir = $cache->subdir('thumbnails');

    $self->_ensure_dir($thumbnails_dir);

    return $thumbnails_dir;
}

sub _dir {
    my $self = shift;

    my $dir = $self->_pick_dir(@_);

    $self->_ensure_dir($dir);

    return $dir;
}

my $TestingRootDir;

sub _pick_dir {
    my $self         = shift;
    my $pieces       = shift;
    my $prod_default = shift;
    my $dev_default  = shift;

    my $config = $self->_config_hash();

    my $key = join '_', @{$pieces};

    return dir( $config->{dirs}{$key} ) if exists $config->{dirs}{$key};

    return dir($prod_default) if $self->is_production();

    return $dev_default if defined $dev_default;

    if ( $ENV{HARNESS_ACTIVE} ) {
        $TestingRootDir ||= tempdir( CLEANUP => 1 );

        return dir( $TestingRootDir, @{$pieces} );
    }

    return dir( $self->_home_dir(), '.milki', @{$pieces} );
}

sub _ensure_dir {
    my $self = shift;
    my $dir  = shift;

    return if -d $dir;

    $dir->mkpath( 0, 0755 ) or die "Cannot make $dir: $!";

    return;
}

sub _build_catalyst_config {
    my $self = shift;

    my %config = (
        default_view => 'Mason',

        'Plugin::Session' => {
            expires => ( 60 * 5 ),

            # Need to quote it for Pg
            dbi_table        => q{"Session"},
            dbi_dbh          => 'Milki::Plugin::Session::Store::Milki',
            object_class     => 'Milki::Web::Session',
            rewrite_body     => 0,
            rewrite_redirect => 1,
        },

        authen_cookie => {
            name       => 'Milki-user',
            path       => '/',
            mac_secret => $self->secret(),
        },

        'Log::Dispatch' => $self->_log_config(),
    );

    $config{root} = $self->share_dir();

    unless ( $self->is_production() ) {
        $config{static} = {
            dirs         => [qw( files images js css static w3c ckeditor )],
            include_path => [
                $self->cache_dir()->stringify(),
                $self->var_lib_dir()->stringify(),
                $self->share_dir()->stringify(),
            ],
            debug => 1,
        };
    }

    return \%config;
}

{

    sub _log_config {
        my $self = shift;

        my @loggers;
        if ( $self->is_production() ) {
            if ( $ENV{MOD_PERL} ) {
                require Apache2::ServerUtil;

                push @loggers, {
                    class     => 'ApacheLog',
                    name      => 'ApacheLog',
                    min_level => 'warning',
                    apache    => Apache2::ServerUtil->server(),
                    callbacks => sub {
                        my %m = @_;
                        return 'milki: ' . $m{message};
                    },
                };
            }
            else {
                require Log::Dispatch::Syslog;

                push @loggers,
                    {
                    class     => 'Syslog',
                    name      => 'Syslog',
                    min_level => 'warning',
                    };
            }
        }
        else {
            push @loggers,
                { class => 'Screen', name => 'Screen', min_level => 'debug', };
        }

        return \@loggers;
    }
}

sub _build_dbi_config {
    my $self = shift;

    my $dsn = 'dbi:Pg:dbname=' . $self->database_name();

    if ( my $host = $self->database_host() ) {
        $dsn .= ';host=' . $host;
    }

    if ( my $port = $self->database_port() ) {
        $dsn .= ';port=' . $port;
    }

    return {
        dsn      => $dsn,
        username => ( $self->database_username() || q{} ),
        password => ( $self->database_password() || q{} ),
    };
}

sub _build_mason_config {
    my $self = shift;

    my %config = (
        comp_root => $self->share_dir()->subdir('mason')->stringify(),
        data_dir  => $self->cache_dir()->subdir( 'mason', 'web' )->stringify(),
        error_mode           => 'fatal',
        in_package           => 'Milki::Mason::Web',
        use_match            => 0,
        default_escape_flags => 'h',
    );

    if ( $self->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $self->_etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _build_mason_config_for_email {
    my $self = shift;

    my %config = (
        comp_root =>
            $self->share_dir()->subdir('email-templates')->stringify(),
        data_dir =>
            $self->cache_dir()->subdir( 'mason', 'email' )->stringify(),
        error_mode => 'fatal',
        in_package => 'Milki::Mason::Email',
    );

    if ( $self->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $self->_etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _build_mason_config_for_help {
    my $self = shift;

    my %config = (
        error_mode           => 'fatal',
        in_package           => 'Milki::Mason::Help',
        default_escape_flags => 'h',
    );

    if ( $self->is_production() ) {
        $config{static_source} = 1;
        $config{static_source_touch_file}
            = $self->_etc_dir()->file('mason-touch')->stringify();
    }

    return \%config;
}

sub _build_static_path_prefix {
    my $self = shift;

    return $self->path_prefix() unless $self->is_production();

    my $prefix = $self->path_prefix();
    $prefix .= q{/};
    $prefix .= $Milki::Config::VERSION || 'wc';

    return $prefix;
}

sub _build_system_hostname {
    for my $name ( hostname(),
        map { scalar gethostbyaddr( $_->address(), AF_INET ) }
        grep { $_->address() } Net::Interface->interfaces() )
    {
        if ( $name =~ /\.[^.]+$/ ) {
            return $name;
        }
        else {
            return $name . '.local';
        }
    }

    die 'Cannot determine system hostname.';
}

sub _build_secret {
    my $self = shift;

    return 'a big secret' unless $self->is_production();

    return $self->_from_config_path('secret');
}

sub write_config_file {
    my $self = shift;
    my ( $file, $values ) = validated_list(
        \@_,
        file   => { isa => File,    coerce  => 1 },
        values => { isa => HashRef, default => {} },
    );

    my %sections;
    for my $attr ( grep { $_->can('description') }
        $self->meta()->get_all_attributes() )
    {

        my $path = $attr->description()->{config_path};

        $sections{ $path->[0] }{ $path->[1] } = $attr;
    }

    my $sort_by_section = sub {
        $a eq 'Milki'
            && $b ne 'Milki' ? -1 : $b eq 'Milki'
            && $a ne 'Milki' ? 1  : lc $a cmp lc $b;
    };

    my $version = $Milki::Config::VERSION || '(working copy)';
    my $content = <<"EOF";
; Config file generated by Milki version $version

EOF
    for my $section ( sort $sort_by_section keys %sections ) {
        $content .= '[' . $section . ']';
        $content .= "\n";

        for my $key (
            sort {
                $sections{$section}{$a}->description()->{key_order}
                    <=> $sections{$section}{$b}->description()->{key_order}
            } keys %{ $sections{$section} }
            )
        {

            my $attr = $sections{$section}{$key};

            my $meta_desc = $attr->description();

            my $wrapped = autoformat( $meta_desc->{description} );
            $wrapped =~ s/\n\n+$/\n/;
            $wrapped =~ s/^/; /gm;

            $content .= $wrapped;

            my $path = join '/', @{ $meta_desc->{config_path} };

            my $value
                = exists $values->{$path}
                ? $values->{$path}
                : $self->_from_config_path( $attr->name() );

            if ( string_is_empty($value) ) {
                $content .= "; $key =";
            }
            else {
                $content .= "$key = $value";
            }

            $content .= "\n\n";
        }
    }

    $file->dir()->mkpath( 0, 0755 );

    write_file( $file->stringify(), $content );

    return;
}

__PACKAGE__->meta()->make_immutable();


# ABSTRACT: Configuration information for Milki

1;
