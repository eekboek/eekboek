#!/usr/bin/perl

use strict;
use warnings;

use lib 'lib';
use EB::Version;

$SIG{INT} = sub { die("No\n") };
print STDERR ("Version = $EB::Version::VERSION -- Continue? ");
<STDIN>;
