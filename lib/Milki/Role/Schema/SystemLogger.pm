package Milki::Role::Schema::SystemLogger;

use strict;
use warnings;
use namespace::autoclean;

use Scalar::Util qw( blessed );
use Milki::Schema::SystemLog;
use Milki::Types qw( ArrayRef Str );

use MooseX::Role::Parameterized;

parameter 'methods' => ( isa => ArrayRef [Str], default => sub { [] }, );

# When creating the very first user, we need to skip logging, because there is
# no user performing the action.
our $SkipLog;

role {
    my $params = shift;

    for my $meth ( @{ $params->methods() } ) {

        my $values_meth = '_system_log_values_for_' . $meth;
        requires $values_meth;

        my $wrapper = sub {
            my $orig = shift;
            my $self = shift;
            my %p    = @_;

            my $user = delete $p{user};

            return $self->$orig(%p) if $SkipLog;

            # XXX - it'd be better to use MX::Params::Validate, but that
            # module doesn't yet allow you to ignore extra arguments, and we
            # have no idea what additional arguments might get passed to
            # $orig.
            unless ( defined $user
                && blessed $user
                && $user->isa('Milki::Schema::User') )
            {

                my $package = ref $self;
                die "Cannot call $package\->$meth without a user parameter";
            }

            my $trans = sub {
                Milki::Schema::SystemLog->insert(
                    user_id => $user->user_id(),
                    $self->$values_meth(%p),
                );

                $self->$orig(%p);
            };

            Milki::Schema->RunInTransaction($trans);
        };

        around $meth => $wrapper;
    }
};

1;

# ABSTRACT: Logs specified actions in the SystemLog table
