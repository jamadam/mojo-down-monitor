#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'extlib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';

use Test::More tests => 12;
use Test::Mojo;

use_ok 'MojoDownMonitor';

# Test
my $t = Test::Mojo->new('MojoDownMonitor');

$t->get_ok('/')->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_like(qr/<\?xml/i)
  ->content_like(qr/Site list \| mojo-down-monitor/i);

$t->get_ok('/', {'X-PJAX' => 'true'})->status_is(200)
  ->content_type_is('text/html;charset=UTF-8')
  ->content_unlike(qr/<\?xml/i)
  ->content_like(qr/Site list \| mojo-down-monitor/i)
  ->content_like(qr/<title/i);
