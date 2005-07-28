#!/usr/bin/perl -w
my $RCS_Id = '$Id: Proof.pm,v 1.2 2005/07/28 16:55:25 jv Exp $ ';

package EB::Report::Proof;

# Author          : Johan Vromans
# Created On      : Wed Jul 27 11:58:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 28 18:55:08 2005
# Update Count    : 21
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

    my $rr = $::dbh->do("SELECT adm_begin FROM Metadata");
    my $date = $rr->[0];
    $rr = $::dbh->do("SELECT now()");

    my $sth;

    $sth = $::dbh->sql_exec("SELECT jnl_acc_id,jnl_amount,acc_desc,acc_balance,acc_ibalance".
			    " FROM Journal, Accounts".
			    " WHERE acc_id = jnl_acc_id".
			    " UNION ".
			    "SELECT acc_id,0,acc_desc,acc_balance,acc_ibalance".
			    " FROM Accounts".
			    " WHERE acc_balance <> 0 OR acc_ibalance <> 0".
			    " ORDER BY jnl_acc_id");

    my $cur = [0];
    my $dtot = 0;
    my $ctot = 0;

    my $fmt = "%5s  %-30s  %10s %10s  %10s %10s\n";
    my $line;
    my @tot;

    my $flush = sub {
	unless ( $line ) {
	    $line = sprintf($fmt, qw(GrBk Grootboekrekening Debet Credit),
			    "Saldo Db", "Saldo Cr");
	    print($line);
	    $line =~ s/./-/g;
	    print($line);
	}
	my ($sd, $sc) = $dtot >= $ctot ? ($dtot - $ctot, 0)
	  : (0, $ctot - $dtot);
	printf($fmt,
	       $cur->[0], $cur->[2], numfmt($dtot), numfmt($ctot),
	       $sd >= 0 ? ( numfmt($sd), "" )
	       : ( "", numfmt($sc) ));
	warn("?Totaal is ".numfmt($dtot - $ctot).", moet zijn ".numfmt($cur->[3])."\n")
	  unless $dtot - $ctot == $cur->[3];
	$tot[0] += $dtot;
	$tot[1] += $ctot;
	$tot[2] += $sd;
	$tot[3] += $sc;
    };

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($acc_id, $amount, $desc, $balance, $ibalance) = @$rr;
	if ( $acc_id != $cur->[0] ) {
	    $flush->() if $cur->[0];
	    if ( $ibalance > 0 ) {
		$dtot = $ibalance; $ctot = 0;
	    }
	    else {
		$ctot = -$ibalance; $dtot = 0;
	    }
	}
	if ( $amount < 0 ) {
	    $ctot -= $amount;
	}
	else {
	    $dtot += $amount;
	}
	$cur = [ @$rr ];
    }
    if ( $cur->[0] ) {
	$flush->();
	print($line);
	printf($fmt, "", "Totaal", map { numfmt($_) } @tot);
    }
}

1;
