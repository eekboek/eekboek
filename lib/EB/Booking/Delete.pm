my $RCS_Id = '$Id: Delete.pm,v 1.4 2005/10/01 13:26:53 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::Delete;

# Author          : Johan Vromans
# Created On      : Mon Sep 19 22:19:05 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct  1 15:26:25 2005
# Update Count    : 52
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use EB;

sub new {
    return bless {};
}

sub perform {
    my ($self, $id, $opts) = @_;

    my $sth;
    my $rr;
    my $orig = $id;
    my ($bsk, $dbsk, $err) = $dbh->bskid($id);
    die("?$err\n") unless defined $bsk;

    # Check if this boekstuk is used by others. This can only be the
    # case if has been paid.

    if ( my $p = $dbh->lookup($bsk, qw(Boekstukken bsk_id bsk_paid)) ) {
	# It has been paid. Show the user the list of bookstukken.
	$sth = $dbh->sql_exec("SELECT dbk_desc, bsk_nr".
			      " FROM Boekstukken,Boekstukregels,Dagboeken".
			      " WHERE bsk_id = bsr_bsk_id".
			      " AND bsk_dbk_id = dbk_id".
			      " AND bsr_id = ?", $p);
	$rr = $sth->fetchall_arrayref;
	if ( $rr ) {
	    my $t = "";
	    foreach ( @$rr ) {
		$t .= join(":", @$_) . " ";
	    }
	    chomp($t);
	    return "?".__x("Boekstuk {bsk} is in gebruik door {lst}",
			   bsk => $dbsk, lst => $t)."\n";
	}
    }

    # Collect list of boekstukregels.
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

    eval {
	# Adjust saldi grootboekrekeningen.
	$sth = $dbh->sql_exec("SELECT jnl_acc_id, jnl_amount".
			      " FROM Journal".
			      " WHERE jnl_bsk_id = ? AND jnl_bsr_seq > 0", $bsk);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    $dbh->upd_account($rr->[0], -$rr->[1]);
	}

	# Delete journal entries.
	$dbh->sql_exec("DELETE FROM Journal".
		       " WHERE jnl_bsk_id = ?", $bsk)->finish;

	# Clear 'paid' info.
	$dbh->sql_exec("UPDATE Boekstukken".
		       " SET bsk_paid = NULL".
		       " WHERE bsk_paid = ?", $_)->finish
			 foreach @bsr;

	# Delete boekstukregels.
	$dbh->sql_exec("DELETE FROM Boekstukregels".
		       " WHERE bsr_bsk_id = ?", $bsk)->finish;

	# Delete boekstuk.
	$dbh->sql_exec("DELETE FROM Boekstukken".
		       " WHERE bsk_id = ?", $bsk)->finish;

	# If we get here, all went okay.
	$dbh->commit;
    };

    if ( $@ ) {
	# It didn't work. Shouldn't happen.
	warn("?".$@);
	$dbh->rollback;
	return "?".__x("Boekstuk {bsk} niet verwijderd",
		       bsk => $dbsk)."\n";
    }

    return __x("Boekstuk {bsk} verwijderd",
	       bsk => $dbsk)."\n";
}

1;
