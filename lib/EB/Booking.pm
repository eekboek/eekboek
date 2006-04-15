# Booking.pm -- Base class for Bookings.
# RCS Info        : $Id: Booking.pm,v 1.11 2006/04/15 09:08:35 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct 15 23:36:51 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Apr 15 10:56:22 2006
# Update Count    : 48
# Status          : Unknown, Use with caution!

my $RCS_Id = '$Id: Booking.pm,v 1.11 2006/04/15 09:08:35 jv Exp $ ';

package main;

our $cfg;
our $dbh;
our $spp;
our $config;

package EB::Booking;

use strict;
use warnings;

use EB;
use EB::Format;

sub new {
    my ($class) = @_;
    $class = ref($class) || $class;
    return bless {} => $class;
}

sub adm_open {
    my ($self) = @_;
    unless ( $dbh->adm_open ) {
	warn("?"._T("De administratie is nog niet geopend")."\n");
	return;
    }
    1;
}

sub bsk_nr {
    my ($self, $opts) = @_;
    my $bsk_nr;
    my $prev = defined($opts->{boekjaar}) && $opts->{boekjaar} ne $dbh->adm("bky");
    if ( $bsk_nr = $opts->{boekstuk} ) {
	my $t = $prev ? "0" : $opts->{dagboek};
	$dbh->set_sequence("bsk_nr_${t}_seq", $bsk_nr+1)
#	  if $dbh->get_sequence("bsk_nr_${t}_seq", "noincr") < $bsk_nr;
    }
    elsif ( $prev ) {
	warn("?"._T("Boekstukken in voorafgaande boekjaren moeten verplicht worden voorzien van een boekstuknummer")."\n");
	return;
	#$bsk_nr = $dbh->get_sequence("bsk_nr_0_seq");
    }
    else {
	$bsk_nr = $dbh->get_sequence("bsk_nr_".$opts->{dagboek}."_seq");
    }
    $bsk_nr;
}

sub begindate {
    my ($self) = @_;

    my $begin;
    my $end;
    if ( $self->{bky} ne $dbh->adm("bky") ) {
	my ($b, $e, $c) = @{$dbh->do("SELECT bky_begin, bky_end, bky_closed".
				     " FROM Boekjaren".
				     " WHERE bky_code = ?", $self->{bky})};
	if ( $c ) {
	    warn("?".__x("Boekjaar {code} is gesloten, er kan niet meer in worden gewijzigd",
		       code => $self->{bky})."\n");
	    return;
	}
	$begin = $b;
	$end = $e;
    }
    elsif ( $dbh->adm("closed") ) {
	warn("?"._T("De administratie is gesloten en kan niet meer worden gewijzigd")."\n");
	return;
    }
    $begin ||= $dbh->adm("begin");
    return $begin unless wantarray;
    $end ||= $dbh->adm("end");
    ($begin, $end);
}

sub in_bky {
    my ($self, $date, $begin, $end) = @_;
    if ( $date lt $begin ) {
	warn("?".__x("De boekingsdatum {date} valt vóór aanvang van dit boekjaar",
		     date => datefmt_full($date))."\n");
	return;
    }
    if ( $date gt $end ) {
	warn("?".__x("De boekingsdatum {date} valt na het einde van dit boekjaar",
		     date => datefmt_full($date))."\n");
	return;
    }
    1;
}

sub amount_with_btw {
    my ($self, $amt, $btw_spec) = @_;
    if ( $amt =~ /^(.+)\@(.+)$/ ) {
	$amt = $1;
	$btw_spec = $2;
    }
    return (amount($amt), $btw_spec);
}

sub parse_btw_spec {
    my ($self, $spec, $btw_id, $kstomz) = @_;
    return (0, undef) unless defined($spec);
    $spec = lc($spec);

    # Quickie for G/N.
    if ( $spec =~ /^([gn])$/ ) {
	return (0, undef);
    }
    # Strip off trailing K|O.
    elsif ( $spec =~ /^(.*)([ko])(.*)$/ ) {
	$kstomz = $2 eq 'k';
	$spec = $1.$3;
    }
    elsif ( $spec =~ /^(.*)([iv])(.*)$/ ) {
	$kstomz = $2 eq 'i';
	$spec = $1.$3;
	warn("!".__x("BTW specificatie {spec}: Gebruik K of O in plaats van I of V",
		     spec => $_[0])."\n");
    }

    # Examine rest. Numeric -> BTW id.
    if ( $spec =~ /^(\d+)$/ ) {
	$btw_id = $1;
    }
    # H L H- L- H+ L+
    elsif ( $spec =~ /^([hl])([-+])?$/ ) {
	$btw_id = $1;
	my $excl;
	$excl = $2 eq '-' if defined $2;
	$btw_id = $dbh->do("SELECT btw_id FROM BTWTabel".
			   " WHERE btw_tariefgroep = ?".
			   " AND ".($excl?"NOT ":"")."btw_incl",
			   $btw_id eq "h" ? BTWTARIEF_HOOG : BTWTARIEF_LAAG)->[0];
    }
    # + -
    elsif ( $spec =~ /^([-+])$/ && $btw_id ) {
	$btw_id = $dbh->do("SELECT btw_id FROM BTWTabel".
			   " WHERE btw_tariefgroep =".
			   " ( SELECT btw_tariefgroep FROM BTWTabel".
			   " WHERE btw_id = ? )".
			   " AND ".($1 eq '-'?"NOT ":"")."btw_incl",
			   $btw_id)->[0];
    }
    elsif ( $spec ne '' ) {
	return;
    }
    ($btw_id, $kstomz);
}

#### Class method
sub norm_btw {
    my ($self, $bsr_amt, $bsr_btw_id) = @_;
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

#### Class method
sub journalise {
    my ($self, $bsk_id) = @_;

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
	      @{$self->norm_btw($bsr_amount, $bsr_btw_id)};
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
