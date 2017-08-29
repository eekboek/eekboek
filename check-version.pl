#!/usr/bin/perl

use strict;
use warnings;

use lib::EB::Version;

$SIG{INT} = sub { die("No\n") };
print STDERR ("Version = $EB::Version::VERSION -- Continue? ");
<STDIN>;
