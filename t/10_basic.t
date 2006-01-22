# $Id: 10_basic.t,v 1.2 2006/01/22 17:07:21 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 7;

# Some basic tests.

BEGIN {
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
