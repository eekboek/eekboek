# $Id: 81_sqlite.t,v 1.3 2008/03/07 10:15:57 jv Exp $  -*-perl-*-

use strict;
use warnings;

use Test::More tests => 4;

# Some basic tests.

BEGIN {
    use_ok("DBI");
}

SKIP: {
    eval { require DBD::SQLite };

    skip("DBI SQLite driver (DBD::SQLite) not installed", 3) if $@;

    # Check minimal interface version.
    my $minpg = 1.12;
    ok($DBD::SQLite::VERSION >= $minpg,
       "DBD::SQLite version = $DBD::SQLite::VERSION,".
       " should be at least $minpg");

    my $tmpdb = "tmp$$.db";

    SKIP: {
	skip("Database tests skipped on request", 2)
	  if $ENV{EB_SKIPDBTESTS};

	# Check whether we can contact the database.
	open(my $db, ">", $tmpdb);
	close($db);
	my $dbh;
	eval {
	    $dbh = DBI->connect("dbi:SQLite:dbname=$tmpdb");
	    ok(!$DBI::errstr, "Database Connect");
	    diag("Connect error:\n\t" . ($DBI::errstr||"")) if $DBI::errstr;
	};
	ok($dbh, "Check databases");
    }
    unlink($tmpdb);
}
