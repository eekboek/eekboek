# $Id: 10_basic.t,v 1.4 2006/06/05 19:38:19 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 10;

# Some basic tests.

BEGIN {
    @ARGV = qw(-X);
    use_ok("EB::Config", "EekBoek");
    use_ok("EB");
    use_ok("EB::Format");
    use_ok("EB::Booking::IV");
    use_ok("EB::Booking::BKM");
}

# Check some data files.

foreach ( qw(eekboek.sql sample.dat) ) {
    my $t = findlib("schema/$_");
    ok(-s $t, $t);
}

foreach ( qw(eekboek balans balres) ) {
    my $t = findlib("css/$_.css");
    ok(-s $t, $t);
}
