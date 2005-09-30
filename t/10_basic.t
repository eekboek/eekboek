# $Id: 10_basic.t,v 1.1 2005/09/30 08:16:22 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 6;

# Some basic tests.

BEGIN {
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
