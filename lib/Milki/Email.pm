package Milki::Email;

use strict;
use warnings;

use Email::Date qw( format_date );
use Email::MessageID;
use Email::MIME::CreateHTML;
use Email::Sender::Simple qw( sendmail );
use HTML::Mason::Interp;
use HTML::TreeBuilder;
use MooseX::Params::Validate qw( validated_list );
use Milki::Config;
use Milki::HTML::FormatText;
use Milki::Schema::User;
use Milki::Types qw( Str HashRef );

use Sub::Exporter -setup => { exports => ['send_email'] };

my $Body;
my $Interp = HTML::Mason::Interp->new(
    out_method => \$Body,
    %{ Milki::Config->new()->mason_config_for_email() },
);

sub send_email {
    my ( $from, $to, $subject, $template, $args ) = validated_list(
        \@_,
        from => {
            isa     => Str,
            default => Milki::Schema::User->SystemUser()->email_address(),
        },
        to              => { isa => Str },
        subject         => { isa => Str },
        template        => { isa => Str },
        template_params => { isa => HashRef, default => {}, },
    );

    my $html_body = _execute_template( $template, $args );

    my $text_body = Milki::HTML::FormatText->new( leftmargin => 0 )
        ->format_string($html_body);

    my $version = $Milki::Email::VERSION || 'from working copy';

    my $email = Email::MIME->create_html(
        header => [
            From         => $from,
            To           => $to,
            Subject      => $subject,
            'Message-ID' => Email::MessageID->new()->in_brackets(),
            Date         => format_date(),
            'X-Sender'   => "Milki version $version",
        ],
        body            => $html_body,
        body_attributes => { content_type => 'text/html; charset=utf-8' },
        text_body_attributes =>
            { content_type => 'text/plain; charset=utf-8' },
        text_body => $text_body,
    );

    sendmail($email);

    return;
}

sub _execute_template {
    my $template = shift;
    my $args     = shift;

    $Body = q{};
    $Interp->exec( q{/} . $template . '.html', %{$args} );

    return $Body;
}

{

    package Milki::Mason::Email;

    use Milki::I18N qw( loc );
    use Milki::Util qw( string_is_empty );
}

1;

# ABSTRACT: Sends email from a template
