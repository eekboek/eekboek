#! perl

use strict;
use warnings;

our $tag = "admtest_bsknr0";
our $dbdriver = "postgres";

unshift( @INC, "t" ) if -d "t";
require "admtest_common.pl";

1;
