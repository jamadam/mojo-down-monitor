#!/usr/bin/env perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'MojoDownMonitor',
    VERSION_FROM => 'lib/MojoDownMonitor.pm',
    AUTHOR       => 'jamadam <sugama@jamadam.com>',
    PREREQ_PM    => {
        'DBD::SQLite'               => '1.35',
        'Try::Tiny'                 => '0.11',
        'SQL::OOP'                  => '0.20',
        'Mojolicious'               => '2.51',
        'Authen::SASL'              => '2,15',
        'Net::SMTP::SSL'            => '1.01',
        'Time::Piece'               => '1.20',
        'EV'                        => '4.03',
        'AnyEvent'                  => '6.13',
    },
    EXE_FILES => ['mojo-down-monitor'],
    test         => {TESTS => 't/*.t'}
);
