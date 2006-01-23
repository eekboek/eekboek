# $Id: 10_basic.t,v 1.3 2006/01/23 10:31:14 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 7;

# Some basic tests.

BEGIN {
    @ARGV = qw(-X);
    use_ok("EB::Config", "EekBoek");
    use_ok("EB");
    use_ok("EB::Shell");
    use_ok("EB::Booking::IV");
    use_ok("EB::Booking::BKM");
}

# Check some data files.

foreach ( qw(eekboek.sql sample.dat) ) {
    my $t = EB_LIB . "EB/schema/$_";
    ok(-s $t, $t);
}
