#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'extlib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';
use MojoDownMonitor::Sites;

use Test::More tests => 12;
use Test::Mojo;

my $site = MojoDownMonitor::Sites->new;
