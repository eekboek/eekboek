#!/usr/bin/perl -w

package main;

our $dbh;
our $config;
our $app;

package EB::Finance;

use EB;
use EB::Expression;

use strict;

use base qw(Exporter);

my $stdfmt0;
my $stdfmtw;
my $btwfmt0;
my $btwfmtw;

our @EXPORT;
BEGIN {
    push(@EXPORT, qw(amount numdebcrd numfmt numfmtw numfmtv numround btwfmt));
    $stdfmt0 = '%.' . AMTPRECISION . 'f';
    $stdfmtw = '%' . AMTWIDTH . "." . AMTPRECISION . 'f';
    $btwfmt0 = '%.' . (BTWPRECISION-2) . 'f';
    $btwfmtw = '%' . BTWWIDTH . "." . (BTWPRECISION-2) . 'f';
}

my $numpat;
my $btwpat;
my $decimalpt;

BEGIN {
    $numpat = qr/^([-+])?(\d+)?(?:[.,])?(\d{1,@{[AMTPRECISION]}})?$/;
    $btwpat = qr/^([-+])?(\d+)?(?:[.,])?(\d{1,@{[BTWPRECISION-2]}})?$/;
    $decimalpt = _T(",");
}

sub amount {
    if ( @_ == 2 ) {
	my ($amt, $btw_id) = @_;
	if ( $amt =~ /^(.+)\@(.+)$/ ) {
	    $amt = $1;
	    $btw_id = $2;
	}
	return (amount($amt), $btw_id);
    }

    my $val = shift;
    if ( $val =~ /.[-+*\/\(\)]/ ) {
	my $expr = EB::Expression->new;
	my $tree = $expr->Parse($val);
	$val = sprintf($stdfmt0, $expr->EvalToScalar($tree));
    }

    return undef unless $val =~ $numpat;
    my ($s, $w, $f) = ($1 || "", $2 || 0, $3 || 0);
    $f .= "0" x (AMTPRECISION - length($f));
    return 0 + ($s.$w.$f);
}

sub numfmt {
    my $v = shift;
    if ( $v == int($v) && $v >= 0 ) {
	$v = ("0" x (AMTPRECISION - length($v) + 1)) . $v if length($v) <= AMTPRECISION;
	substr($v, length($v) - AMTPRECISION, 0) = $decimalpt;
    }
    else {
	$v = sprintf($stdfmt0, $v/AMTSCALE);
	$v =~ s/\./$decimalpt/;
    }
    $v;
}

sub numfmtw {
    my $v = shift;
    if ( $v == int($v) && $v >= 0  ) {
	$v = ("0" x (AMTPRECISION - length($v) + 1)) . $v if length($v) <= AMTPRECISION;
	$v = (" " x (AMTWIDTH - length($v))) . $v if length($v) < AMTWIDTH;
	substr($v, length($v) - AMTPRECISION, 0) = $decimalpt;
    }
    else {
	$v = sprintf($stdfmtw, $v/AMTSCALE);
	$v =~ s/\./$decimalpt/;
    }
    $v;
}

sub numfmtv {
    my $v = shift;
    if ( $v == int($v) && $v >= 0  ) {
	$v = ("0" x (AMTPRECISION - length($v) + 1)) . $v if length($v) <= AMTPRECISION;
	$v = (" " x ($_[0] - length($v))) . $v if length($v) < $_[0];
	substr($v, length($v) - AMTPRECISION, 0) = $decimalpt;
    }
    else {
	$v = sprintf('%'.$_[0].'.'.AMTPRECISION.'f', $v/AMTSCALE);
	$v =~ s/\./$decimalpt/;
    }
    $v;
}

sub numround {
    0 + sprintf("%.0f", $_[0]);
}

sub numdebcrd {
    $_[0] >= 0 ? ($_[0], undef) : (undef, -$_[0]);
}

sub btwfmt {
    my $v = sprintf($btwfmt0, 100*$_[0]/BTWSCALE);
    $v =~ s/\./$decimalpt/;
    $v;
}

sub norm_btw {
    my ($bsr_amt, $bsr_btw_id);
    my ($btw_perc, $btw_incl, $btw_acc_inkoop, $btw_acc_verkoop);
    if ( @_ == 2 ) {
	($bsr_amt, $bsr_btw_id) = @_;
	if ( $bsr_btw_id ) {
	    my $rr = $dbh->do("SELECT btw_perc, btw_incl, btw_tariefgroep".
			      " FROM BTWTabel".
			      " WHERE btw_id = ?", $bsr_btw_id);
	    my $group;
	    ($btw_perc, $btw_incl, $group) = @$rr;
	    if ( $group == BTWTYPE_HOOG ) {
		$btw_acc_inkoop = $dbh->std_acc("btw_ih");
		$btw_acc_verkoop = $dbh->std_acc("btw_vh");
	    }
	    else {
		$btw_acc_inkoop = $dbh->std_acc("btw_il");
		$btw_acc_verkoop = $dbh->std_acc("btw_vl");
	    }
	}
    }
    else {
	($bsr_amt, $btw_perc, $btw_incl) = @_;
    }

    my $bruto = $bsr_amt;
    my $netto = $bsr_amt;

    if ( $btw_perc ) {
	if ( $btw_incl ) {
	    $netto = numround($bruto * (1 / (1 + $btw_perc/BTWSCALE)));
	}
	else {
	    $bruto = numround($netto * (1 + $btw_perc/BTWSCALE));
	}
    }

    [ $bruto, $bruto - $netto, $btw_acc_inkoop, $btw_acc_verkoop ];
}

sub journalise {
    my ($bsk_id) = @_;

    # date  bsk_id  bsr_seq(0)   dbk_id  (acc_id) amount debcrd desc(bsk) (rel)
    # date (bsk_id) bsr_seq(>0) (dbk_id)  acc_id  amount debcrd desc(bsr) rel(acc=1200/1600)
    my ($jnl_date, $jnl_bsk_id, $jnl_bsr_seq, $jnl_dbk_id, $jnl_acc_id,
	$jnl_amount, $jnl_desc, $jnl_rel);

    my $rr = $::dbh->do("SELECT bsk_nr, bsk_desc, bsk_dbk_id, bsk_date".
		      " FROM boekstukken".
		      " WHERE bsk_id = ?", $bsk_id);
    my ($bsk_nr, $bsk_desc, $bsk_dbk_id, $bsk_date) = @$rr;

    my ($dbktype, $dbk_acc_id) =
      @{$::dbh->do("SELECT dbk_type, dbk_acc_id".
		 " FROM Dagboeken".
		 " WHERE dbk_id = ?", $bsk_dbk_id)};
    my $sth = $::dbh->sql_exec("SELECT bsr_id, bsr_nr, bsr_date, ".
			     "bsr_desc, bsr_amount, bsr_btw_id, ".
			     "bsr_btw_acc, bsr_type, bsr_acc_id, bsr_rel_code ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?", $bsk_id);

    my $ret = [];
    my $tot = 0;
    my $nr = 1;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount,
	    $bsr_btw_id, $bsr_btw_acc, $bsr_type, $bsr_acc_id, $bsr_rel_code) = @$rr;
	my $bsr_bsk_id = $bsk_id;

#	# Flip sign for credit accounts.
#	$bsr_amount = -$bsr_amount
#	  unless $::dbh->lookup($bsr_acc_id,
#				qw(Accounts acc_id acc_debcrd));

	my $btw = 0;
	my $amt = $bsr_amount;

	if ( $bsr_btw_id && $bsr_btw_acc ) {
	    ( $bsr_amount, $btw ) =
	      @{EB::Finance::norm_btw($bsr_amount, $bsr_btw_id)};
	    $amt = $bsr_amount - $btw;
	}
	$tot += $bsr_amount;

	push(@$ret, [$bsk_date, $bsk_dbk_id, $bsk_id, $bsr_date, $nr++,
		     $bsr_acc_id,
		     $bsr_amount - $btw, $bsr_desc,
		     $bsr_type ? $bsr_rel_code : undef]);
	push(@$ret, [$bsk_date,  $bsk_dbk_id, $bsk_id, $bsr_date, $nr++,
		     $bsr_btw_acc,
		     $btw, "BTW ".$bsr_desc,
		     undef]) if $btw;
    }

    push(@$ret, [$bsk_date,  $bsk_dbk_id, $bsk_id, $bsk_date, $nr++, $dbk_acc_id,
		 -$tot, $bsk_desc, undef])
      unless $dbktype == DBKTYPE_MEMORIAAL;

    unshift(@$ret, [$bsk_date, $bsk_dbk_id, $bsk_id, $bsk_date, 0, undef,
		    undef, $bsk_desc, undef]);

    $ret;
}

1;
