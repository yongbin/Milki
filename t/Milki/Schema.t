use strict;
use warnings;

use Test::Most;

use lib 't/lib';
use Milki::Test::FakeSchema;

use Milki::Schema;

lives_ok { Milki::Schema->LoadAllClasses() } 'call LoadAllClasses';

done_testing();
