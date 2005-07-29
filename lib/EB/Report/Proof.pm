#!/usr/bin/perl -w
my $RCS_Id = '$Id: Proof.pm,v 1.4 2005/07/29 16:14:16 jv Exp $ ';

package EB::Report::Proof;

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Jul 29 18:12:24 2005
# Update Count    : 225
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

sub proefensaldibalans {
    my ($self, $opts) = @_;
    $self->perform($opts);
}

sub perform {
    my ($self, $opts) = @_;

    my $detail = $opts->{detail};
    $detail = $opts->{verdicht} ? 2 : -1 unless defined $detail;

    my @grand = (0) x 4;	# grand total
    my $rep = new EB::Report::Text(detail   => $detail,
				   verdicht => $detail >= 0,
				   proef    => 1);

    my $rr = $::dbh->do("SELECT adm_begin FROM Metadata");
    my $date = $rr->[0];
    $rr = $::dbh->do("SELECT now()");
    $rep->addline('H', '',
		  "Proef- en Saldibalans" .
		  " -- Periode $date - " .
		  substr($rr->[0],0,10));

    my $sth;

    my $hvd_hdr;
    my $vd_hdr;

    my $journaal = sub {
	my ($acc_id, $acc_desc, $acc_ibalance) = @_;
	my @tot = (0) x 4;
	my $did = 0;
	if ( $acc_ibalance ) {
	    $did++;
	    if ( $acc_ibalance < 0 ) {
		$tot[1] = -$acc_ibalance;
	    }
	    else {
		$tot[0] = $acc_ibalance;
	    }
	    # $rep->addline('D2', '', 'Beginsaldo', @tot);
	}
	my $sth = $::dbh->sql_exec
	  ("SELECT jnl_amount,jnl_desc".
	   " FROM Journal".
	   " WHERE jnl_acc_id = ?".
	   " ORDER BY jnl_date", $acc_id);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($amount, $desc) = @$rr;
	    $did++;
	    my @t = (0) x 4;
	    $t[$amount<0] += abs($amount);
	    # $rep->addline('D2', '', $desc, @t);
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	$tot[0] ||= "00" if $did;
	$tot[1] ||= "00" if $did;
	@tot;
    };
    my $grootboeken = sub {
	my ($vd, $hvd) = shift;
	my @tot = (0) x 4;
	my $sth = $::dbh->sql_exec
	  ("SELECT acc_id, acc_desc, acc_balance, acc_ibalance".
	   " FROM Accounts".
	   " WHERE acc_struct = ?".
	   " AND ( acc_ibalance <> 0".
	   "       OR acc_id IN ( SELECT DISTINCT jnl_acc_id FROM Journal ))".
	   " ORDER BY acc_id", $vd->[0]);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($acc_id, $acc_desc, $acc_balance, $acc_ibalance) = @$rr;
	    my @t = $journaal->($acc_id, $acc_desc, $acc_ibalance);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    next unless $detail > 1;
	    $rep->addline('H1', @$hvd_hdr), undef $hvd_hdr if $hvd_hdr;
	    $rep->addline('H2', @$vd_hdr), undef $vd_hdr if $vd_hdr;
	    $rep->addline('D2', $acc_id, $acc_desc, @t);
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	@tot;
    };
    my $verdichtingen = sub {
	my ($hvd) = shift;
	my @tot = (0) x 4;
	my $did = 0;
	foreach my $vd ( @{$hvd->[2]} ) {
	    next unless defined $vd;
	    $vd_hdr = [ $vd->[0], $vd->[1] ];
	    my @t = $grootboeken->($vd, $hvd);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    next unless $detail > 0;
	    $rep->addline('H1', @$hvd_hdr), undef $hvd_hdr if $hvd_hdr;
	    $rep->addline('T2', $vd->[0], "Totaal ".$vd->[1], @t);
	}
	if ( $tot[0] >= $tot[1] ) {
	    $tot[2] = $tot[0] - $tot[1]; $tot[3] = 0;
	}
	else {
	    $tot[3] = $tot[1] - $tot[0]; $tot[2] = 0;
	}
	@tot;
    };
    my $hoofdverdichtingen = sub {
	my (@hvd) = @_;
	my @tot = (0) x 4;
	foreach my $hvd ( @hvd ) {
	    next unless defined $hvd;
	    $hvd_hdr = [ $hvd->[0], $hvd->[1] ];
	    my @t = $verdichtingen->($hvd);
	    next if "@t" eq "0 0 0 0";
	    $rep->addline('H1', @$hvd_hdr), undef $hvd_hdr if $detail && $hvd_hdr;
	    $rep->addline('T1', $hvd->[0], "Totaal ".$hvd->[1], @t);
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	}
	@tot;
    };

    if ( $detail >= 0 ) {	# Verdicht
	my @vd;
	my @hvd;
	$sth = $::dbh->sql_exec("SELECT vdi_id, vdi_desc".
				" FROM Verdichtingen".
				" WHERE vdi_struct IS NULL".
				" ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    $hvd[$rr->[0]] = [ @$rr, []];
	}

	@vd = @hvd;
	$sth = $::dbh->sql_exec("SELECT vdi_id, vdi_desc, vdi_struct".
				" FROM Verdichtingen".
				" WHERE vdi_struct IS NOT NULL".
				" ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    push(@{$hvd[$rr->[2]]->[2]}, [@$rr]);
	    @vd[$rr->[0]] = [@$rr];
	}

	my @tot = $hoofdverdichtingen->(@hvd);
	$rep->addline('T', '', 'TOTAAL', @tot);
    }

    else {			# Op Grootboek

	my @tot = (0) x 4;
	my $sth = $::dbh->sql_exec
	  ("SELECT acc_id, acc_desc, acc_balance, acc_ibalance".
	   " FROM Accounts".
	   " WHERE ( acc_ibalance <> 0".
	   "         OR acc_id IN ( SELECT DISTINCT jnl_acc_id FROM Journal ))".
	   " ORDER BY acc_id");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($acc_id, $acc_desc, $acc_balance, $acc_ibalance) = @$rr;
	    my @t = $journaal->($acc_id, $acc_desc, $acc_ibalance);
	    next if "@t" eq "0 0 0 0";
	    $tot[$_] += $t[$_] foreach 0..$#tot;
	    $rep->addline('D', $acc_id, $acc_desc, @t);
	}
	$rep->addline('T', '', 'TOTAAL', @tot);
    }
}

1;
