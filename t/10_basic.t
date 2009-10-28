# $Id: 10_basic.t,v 1.9 2009/10/28 22:43:05 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 11;

# Some basic tests.

BEGIN {
    use_ok("EB::Config", { app => "Test", nostdconf => 1 } );
    use_ok("EB");
    use_ok("EB::Format");
    use_ok("EB::Booking::IV");
    use_ok("EB::Booking::BKM");
}

# Check some data files.

foreach ( qw(eekboek.sql) ) {
    my $t = findlib("schema/$_");
    ok(-s $t, $t);
}

foreach ( qw(schema.dat bvnv.dat) ) {
    my $t = findlib("examples/$_");
    ok(-s $t, $t);
}

foreach ( qw(eekboek balans balres) ) {
    my $t = findlib("css/$_.css");
    ok(-s $t, $t);
}
