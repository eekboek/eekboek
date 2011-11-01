#! perl

# $Id: 90_ivp_common.pl,v 1.5 2009/10/28 22:12:17 jv Exp $  -*-perl-*-

use strict;
use warnings;

our $tag = "admtest_result";
our $dbdriver = "sqlite";

unshift( @INC, "t" ) if -d "t";
require "admtest_common.pl";

1;
