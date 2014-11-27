use strict;
use warnings;

use Test::Most;

# For the benefit of Data::Localize
BEGIN { $ENV{ANY_MOOSE} = 'Moose' }

use Milki::I18N;

Milki::I18N->SetLanguage('fr');

is( Milki::I18N->Language(), 'fr', 'Language is fr' );

done_testing();
