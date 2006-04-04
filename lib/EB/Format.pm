#!/usr/bin/perl -w

package main;

our $cfg;
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
my $numpat;
my $btwpat;
my $decimalpt;
my $thousandsep;

our @EXPORT;
our $amount_width;
our $date_width;

sub _setup  {

    ################ BTW display format ################

    $btwfmt0 = '%.' . (BTWPRECISION-2) . 'f';
    $btwfmtw = '%' . BTWWIDTH . "." . (BTWPRECISION-2) . 'f';
    $btwpat = qr/^([-+])?(\d+)?(?:[.,])?(\d{1,@{[BTWPRECISION-2]}})?$/;

    ################ Amount display format ################

    $amount_width = $cfg->val(qw(text numwidth), AMTWIDTH);
    if ( $amount_width =~ /^\+(\d+)$/ ) {
	$amount_width = AMTWIDTH + $1;
    }
    elsif ( $amount_width =~ /^\-(\d+)$/ ) {
	$amount_width = AMTWIDTH - $1;
    }
    elsif ( $amount_width =~ /^(\d+)%$/ ) {
	$amount_width = int((AMTWIDTH * $1) / 100);
    }
    elsif ( $amount_width !~ /^\d+$/ ) {
	warn("?"._T("Configuratiefout: [format]numwidth moet een getal zijn")."\n");
	$amount_width = AMTWIDTH;
    }
    $decimalpt = $cfg->val(qw(locale decimalpt), _T(","));
    $thousandsep = $cfg->val(qw(locale thousandsep), "");
    $amount_width += int(($amount_width - AMTPRECISION - 2) / 3) if $thousandsep;

    $stdfmt0 = '%.' . AMTPRECISION . 'f';
    $stdfmtw = '%' . $amount_width . "." . AMTPRECISION . 'f';

    my $sub = "";

    $sub .= <<EOD;
    my \$v = shift;
    if ( \$v == int(\$v) && \$v >= 0 ) {
	\$v = ("0" x (@{[AMTPRECISION + 1]} - length(\$v))) . \$v if length(\$v) <= @{[AMTPRECISION]};
	substr(\$v, length(\$v) - @{[AMTPRECISION]}, 0) = q\000$decimalpt\000;
    }
    else {
	\$v = sprintf("$stdfmt0", \$v/@{[AMTSCALE]});
EOD
    $sub .= <<EOD if $decimalpt ne '.';
	\$v =~ s/\\./$decimalpt/;
EOD
    $sub .= <<EOD;
    }
EOD

    eval("sub numfmt_plain { $sub; \$v }");
    die($@) if $@;

    $sub .= <<EOD if $thousandsep;
    \$v = reverse(\$v);
    \$v =~ s/(\\d\\d\\d)(?=\\d)(?!\\d*@{[quotemeta($decimalpt)]})/\${1}$thousandsep/g;
    scalar(reverse(\$v));
EOD
    $sub .= <<EOD if !$thousandsep;
    \$v;
EOD

    eval("sub numfmt { $sub }");
    die($@) if $@;

    $numpat = qr/^([-+])?(\d+)?(?:[.,])?(\d{1,@{[AMTPRECISION]}})?$/;

    ################ Date display format ################

    my $fmt = $cfg->val(qw(format date), "YYYY-MM-DD");

    $sub          = "sub datefmt { \$_[0] }";
    my $sub_full  = "sub datefmt_full { \$_[0] }";
    my $sub_plain = "sub datefmt_plain { \$_[0] }";
    if ( lc($fmt) eq "dd-mm-yyyy" ) {
	$sub      = q<sub datefmt { join("-", reverse(split(/-/, $_[0]))) }>;
	$sub_full = q<sub datefmt_full { join("-", reverse(split(/-/, $_[0]))) }>;
    }
    elsif ( lc($fmt) eq "dd-mm" ) {
	$sub      = q<sub datefmt { $_[0] =~ /(\d+)-(\d+)-(\d+)/; "$3-$2" }>;
	$sub_full = q<sub datefmt_full { join("-", reverse(split(/-/, $_[0]))) }>;
    }
    elsif ( lc($fmt) ne "yyyy-mm-dd" ) {
	die("?".__x("Ongeldige datumformaatspecificatie: {fmt}",
		    fmt => $fmt)."\n");
    }
    for ( $sub, $sub_full, $sub_plain ) {
	eval($_);
	die($_."\n".$@) if $@;
    }
    $date_width = length(datefmt("2006-01-01"));
}

BEGIN {
    push(@EXPORT, qw(amount numround btwfmt));
    push(@EXPORT, qw($amount_width numfmt numfmt_plain));
    push(@EXPORT, qw($date_width datefmt datefmt_full datefmt_plain));
    _setup();
}

sub amount($) {
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

#### USED BY GUI
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

#### UNUSED
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
    # This somethimes does odd things.
    # E.g. 892,5 -> 892 and 891,5 -> 892.
    0 + sprintf("%.0f", $_[0]);
}

=begin alternative

# Is this a beteer alternative?

use POSIX qw(floor ceil);

sub numround {
    my ($val) = @_;
    if ( $val < 0 ) {
	ceil($val - 0.5);
    }
    else {
	floor($val + 0.5);
    }
}

=cut

sub btwfmt {
    my $v = sprintf($btwfmt0, 100*$_[0]/BTWSCALE);
    $v =~ s/\./$decimalpt/;
    $v;
}

sub norm_btw {
    my ($bsr_amt, $bsr_btw_id) = @_;
    my ($btw_perc, $btw_incl);
    if ( $bsr_btw_id ) {
	my $rr = $dbh->do("SELECT btw_perc, btw_incl".
			  " FROM BTWTabel".
			  " WHERE btw_id = ?", $bsr_btw_id);
	($btw_perc, $btw_incl) = @$rr;
    }

    return [ $bsr_amt, 0 ] unless $btw_perc;

    my $bruto = $bsr_amt;
    my $netto = $bsr_amt;

    if ( $btw_incl ) {
	$netto = numround($bruto * (1 / (1 + $btw_perc/BTWSCALE)));
    }
    else {
	$bruto = numround($netto * (1 + $btw_perc/BTWSCALE));
    }

    [ $bruto, $bruto - $netto ];
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
			     "bsr_desc, bsr_amount, bsr_btw_class, bsr_btw_id, ".
			     "bsr_btw_acc, bsr_type, bsr_acc_id, bsr_rel_code ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?", $bsk_id);

    my $ret = [];
    my $tot = 0;
    my $nr = 1;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount, $bsr_btw_class,
	    $bsr_btw_id, $bsr_btw_acc, $bsr_type, $bsr_acc_id, $bsr_rel_code) = @$rr;
	my $bsr_bsk_id = $bsk_id;
	my $btw = 0;
	my $amt = $bsr_amount;

	if ( ($bsr_btw_class & BTWKLASSE_BTW_BIT) && $bsr_btw_id && $bsr_btw_acc ) {
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
      if $dbk_acc_id;

    unshift(@$ret, [$bsk_date, $bsk_dbk_id, $bsk_id, $bsk_date, 0, undef,
		    undef, $bsk_desc, undef]);

    $ret;
}

1;
