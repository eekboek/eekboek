# $Id: 10_basic.t,v 1.7 2008/02/25 11:49:37 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 11;

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
