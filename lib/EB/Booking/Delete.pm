my $RCS_Id = '$Id: Delete.pm,v 1.1 2005/09/20 16:11:25 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::Delete;

# Author          : Johan Vromans
# Created On      : Mon Sep 19 22:19:05 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 20 17:53:00 2005
# Update Count    : 36
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use EB;

my $trace_updates = $ENV{EB_TRACE_UPDATES};		# for debugging

sub new {
    return bless {};
}

sub perform {
    my ($self, $args, $opts) = @_;
    my $id = shift(@$args);

    my $sth;
    my $rr;
    my $orig = $id;
    my $bsk = $dbh->bskid($id);

    my $p = $dbh->lookup($bsk, qw(Boekstukken bsk_id bsk_paid));

    if ( $p ) {
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_dbk_id, bsk_nr".
			      " FROM Boekstukken,Boekstukregels".
			      " WHERE bsk_id = bsr_bsk_id".
			      " AND bsr_id = ?", $p);
	$rr = $sth->fetchall_arrayref;
	if ( $rr ) {
	    my $t = "";
	    foreach ( @$rr ) {
		$t .= $dbh->lookup($_->[1], qw(Dagboeken dbk_id dbk_desc)).
		  ":" . $_->[2] . " ";
	    }
	    chomp($t);
	    return "?".__x("Boekstuk {bsk} is in gebruik door {lst}",
			   bsk => $orig, lst => $t)."\n";
	}
    }

    eval {
	$sth = $dbh->sql_exec("SELECT bsr_id".
			      " FROM Boekstukregels".
			      " WHERE bsr_bsk_id = ?", $bsk);
	$rr = $sth->fetchall_arrayref;
	my @bsr;
	if ( $rr ) {
	    foreach ( @$rr ) {
		push(@bsr, $_->[0]);
	    }
	}
	#### TODO: aanpassen grootbooksaldi.
	$dbh->sql_exec("DELETE FROM Journal".
		       " WHERE jnl_bsk_id = ?", $bsk)->finish;
	$dbh->sql_exec("UPDATE Boekstukken".
		       " SET bsk_paid = NULL".
		       " WHERE bsk_paid = ?", $_)->finish
			 foreach @bsr;
	$dbh->sql_exec("DELETE FROM Boekstukregels".
		       " WHERE bsr_bsk_id = ?", $bsk)->finish;
	$dbh->sql_exec("DELETE FROM Boekstukken".
		       " WHERE bsk_id = ?", $bsk)->finish;
	$dbh->commit;
	return __x("Boekstuk {bsk} verwijderd",
		   bsk => $orig)."\n";
    };
    $dbh->rollback;
    return "?".__x("Boekstuk {bsk} niet verwijderd",
		   bsk => $orig)."\n";
}

1;
