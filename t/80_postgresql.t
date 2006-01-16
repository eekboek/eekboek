# $Id: 80_postgresql.t,v 1.1 2006/01/16 11:07:02 jv Exp $  -*-perl-*-

use strict;
use Test::More tests => 4;

# Some basic tests.

BEGIN {
    use_ok("DBI");
}

SKIP: {
    eval { require DBD::Pg };

    skip("DBI PostgreSQL driver (DBD::Pg) not installed", 3) if $@;

    # Check minimal Pg interface version.
    ok($DBD::Pg::VERSION >= 1.41,
       "DBD::PG version = $DBD::Pg::VERSION, should be at east 1.41");

    SKIP: {
	skip("Database tests skipped on request", 2)
	  if $ENV{EB_SKIPDBTESTS};

	# Check whether we can contact the database.
	my @ds;
	eval {
	    @ds = DBI->data_sources("Pg");
	    ok(!$DBI::errstr, "Database Connect");
	    diag("Connect error:\n\t" . ($DBI::errstr||"")) if $DBI::errstr;
	};
	ok(@ds > 1, "Check databases");
    }
}
