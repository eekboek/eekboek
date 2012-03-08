#! perl

# $Id: 90_ivp_common.pl,v 1.5 2009/10/28 22:12:17 jv Exp $  -*-perl-*-

use strict;
use warnings;

our $tag = "admtest_btw";
our $dbdriver = "postgres";	# SQLite cannot import

unshift( @INC, "t" ) if -d "t";
require "admtest_common.pl";

1;
