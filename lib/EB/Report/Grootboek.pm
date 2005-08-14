#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grootboek.pm,v 1.3 2005/08/14 09:33:54 jv Exp $ ';

package main;

our $config;
our $dbh;
our $app;

package EB::Report::Grootboek;

# Author          : Johan Vromans
# Created On      : Wed Jul 27 11:58:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Aug 14 11:26:17 2005
# Update Count    : 70
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB::Globals;
use EB::DB;
use EB::Finance;
use EB::Report::Text;

use locale;

################ Subroutines ################

sub new {
    return bless {};
}

sub perform {
    my ($self, $opts) = @_;

    my $detail = $opts->{detail};

    my $rr = $dbh->do("SELECT adm_begin FROM Metadata");
    my $date = $rr->[0];
    my $now = $ENV{EB_SQL_NOW} || $dbh->do("SELECT now()")->[0];

    print("Grootboek -- Periode $date - ", substr($now,0,10), "\n\n");

    my $ah = $dbh->sql_exec("SELECT acc_id,acc_desc,acc_ibalance".
			    " FROM Accounts".
			    " WHERE acc_ibalance <> 0".
			    " OR acc_id in".
			    "  ( SELECT DISTINCT jnl_acc_id FROM Journal )".
			    " ORDER BY acc_id");

    my $dgrand = 0;
    my $cgrand = 0;
    my $mdgrand = 0;
    my $mcgrand = 0;
    my $n0 = numfmt(0);

    my $fmt = "%5s  %-30.30s  %4s  %10s %10s %10s  %-10.10s  %4s  %-8s\n";
    my $line;

    while ( my $ar = $ah->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $acc_ibalance) = @$ar;
	unless ( $line ) {
	    $line = sprintf($fmt, qw(GrBk Grootboek/Boekstuk Id Datum Debet Credit Dagboek Nr Relatie));
	    print($line);
	    $line =~ s/./-/g;
	    print($line);
	}
	else {
	    print("\n") if $detail;
	}
	printf($fmt, $acc_id, $acc_desc, ("") x 7) if $detail;

	my @d = ($n0, $n0);
	if ( $acc_ibalance ) {
	    if ( $acc_ibalance > 0 ) {
		$d[0] = numfmt($acc_ibalance);
	    }
	    else {
		$d[1] = numfmt(-$acc_ibalance);
	    }
	}
	printf($fmt, "", " Beginsaldo", "", "", @d, ("") x 3) if $detail > 0;

	my $sth = $dbh->sql_exec("SELECT jnl_amount,jnl_bsk_id,bsk_desc,bsk_nr,dbk_desc,jnl_date,jnl_desc,jnl_rel".
				 " FROM journal, Boekstukken, Dagboeken".
				 " WHERE jnl_dbk_id = dbk_id".
				 " AND jnl_bsk_id = bsk_id".
				 " AND jnl_acc_id = ?".
				 " ORDER BY jnl_acc_id, jnl_date",
				 $acc_id);

	my $dtot = 0;
	my $ctot = 0;
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($amount, $bsk_id, $bsk_desc, $bsk_nr, $dbk_desc, $date, $desc, $rel) = @$rr;

	    if ( $amount < 0 ) {
		$ctot -= $amount;
	    }
	    else {
		$dtot += $amount;
	    }
	    printf($fmt, "", "  " . $desc, $bsk_id, $date,
		   $amount >= 0 ? (numfmt($amount), $n0) : ($n0, numfmt(-$amount)),
		   $dbk_desc, $bsk_nr, $rel||"") if $detail > 1;
	}

	printf($fmt, "", " Totaal mutaties", "", "",
	       $ctot > $dtot ? ("", numfmt($ctot-$dtot)) : (numfmt($dtot-$ctot), ""),
	       ("") x 3) if $detail && ($dtot || $ctot || $acc_ibalance);

	if ( $dtot > $ctot ) {
	    $mdgrand += $dtot - $ctot;
	}
	else {
	    $mcgrand += $ctot - $dtot;
	}

	printf($fmt, $acc_id, "Totaal $acc_desc", "", "",
	       $ctot > $dtot + $acc_ibalance ? ("", numfmt($ctot-$dtot-$acc_ibalance)) : (numfmt($dtot+$acc_ibalance-$ctot),""),
	       ("") x 3);
	if ( $ctot > $dtot + $acc_ibalance ) {
	    $cgrand += $ctot - $dtot-$acc_ibalance;
	}
	else {
	    $dgrand += $dtot+$acc_ibalance - $ctot;
	}
    }

    print("\n");
    printf($fmt, "", "Totaal Mutaties", "", "",
	       numfmt($mdgrand), numfmt($mcgrand),
	       ("") x 3);
    print($line);
    printf($fmt, "", "Totaal", "", "",
	       numfmt($dgrand), numfmt($cgrand),
	       ("") x 3);
}

1;
