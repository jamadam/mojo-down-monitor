use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'extlib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';

use Test::Memory::Cycle;
use Test::More tests => 2;
use Test::Mojo;

use_ok 'MojoDownMonitor';

my $mdm = MojoDownMonitor->new;

memory_cycle_ok($mdm);

__END__