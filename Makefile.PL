#!/usr/bin/env perl

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'MojoDownMonitor',
    VERSION_FROM => 'lib/MojoDownMonitor.pm',
    AUTHOR       => 'jamadam <sugama@jamadam.com>',
    PREREQ_PM    => {
        'Attribute::Handler'        => '0.91',
        'Class::Data::Inheritable'  => '0.08',
        'DBD::SQLite'               => '1.35',
        'Try::Tiny'                 => '0.11',
        'SQL::OOP'                  => '0.15',
        'Mojolicious'               => '2.32',
        'Authen::SASL'              => '2,15',
        'Net::SMTP::SSL'            => '1.01',
        'Time::Piece'               => '1.20',
    },
    test         => {TESTS => 't/*.t'}
);
