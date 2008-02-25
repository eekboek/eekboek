# $Id: 80_postgresql.t,v 1.5 2008/02/25 11:50:16 jv Exp $  -*-perl-*-

use strict;
use warnings;

use Test::More tests => 4;

# Some basic tests.

BEGIN {
    use_ok("DBI");
}

SKIP: {
    eval { require DBD::Pg };

    skip("DBI PostgreSQL driver (DBD::Pg) not installed", 3) if $@;

    # Check minimal Pg interface version.
    my $minpg = 1.31;
    ok($DBD::Pg::VERSION >= $minpg,
       "DBD::PG version = $DBD::Pg::VERSION, should be at east $minpg");

    SKIP: {
	skip("Database tests skipped on request", 2)
	  if $ENV{EB_SKIPDBTESTS};

	# Check whether we can contact the database.
	my @ds;
	eval {
	    @ds = DBI->data_sources("Pg");

	    skip("No access to database", 2)
	      if $DBI::errstr && $DBI::errstr =~ /FATAL:\s*role .* does not exist/;

	    ok(!$DBI::errstr, "Database Connect");
	    diag("Connect error:\n\t" . ($DBI::errstr||"")) if $DBI::errstr;
	};
	ok(@ds > 1, "Check databases");
    }
}
