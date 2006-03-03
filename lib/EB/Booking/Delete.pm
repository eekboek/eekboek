my $RCS_Id = '$Id: Delete.pm,v 1.6 2006/03/03 21:43:40 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::Delete;

# Author          : Johan Vromans
# Created On      : Mon Sep 19 22:19:05 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar  3 22:41:32 2006
# Update Count    : 65
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

    my ($amt, $open) = @{$dbh->do("SELECT bsk_amount,bsk_open".
				  " FROM Boekstukken".
				  " WHERE bsk_id = ?", $bsk)};
    if ( defined($open) && $amt != $open ) {
	# It has been paid. Show the user the list of bookstukken.
	$sth = $dbh->sql_exec("SELECT dbk_desc, bsk_nr".
			      " FROM Boekstukken,Boekstukregels,Dagboeken".
			      " WHERE bsk_id = bsr_bsk_id".
			      " AND bsk_dbk_id = dbk_id".
			      " AND bsr_paid = ?", $bsk);
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

    # Collect list of affectec boekstukken.
    $sth = $dbh->sql_exec("SELECT bsr_paid,bsr_amount".
			  " FROM Boekstukregels".
			  " WHERE bsr_paid IS NOT NULL AND bsr_bsk_id = ?", $bsk);
    $rr = $sth->fetchall_arrayref;
    my @bsk; my @amt;
    if ( $rr ) {
	foreach ( @$rr ) {
	    push(@bsk, $_->[0]);
	    push(@amt, $_->[1]);
	}
    }

    eval {
	# Adjust saldi grootboekrekeningen.
	# Hoewel in veel gevallen niet nodig, is het toch noodzakelijk i.v.m.
	# de saldi van bankrekeningen.
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
		       " SET bsk_open = bsk_open - ?".
		       " WHERE bsk_id = ?", shift(@amt), $_)->finish
			 foreach @bsk;

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
