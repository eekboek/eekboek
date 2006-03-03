# Booking.pm -- Base class for Bookings.
# RCS Info        : $Id: Booking.pm,v 1.6 2006/03/03 21:17:40 jv Exp $
# Author          : Johan Vromans
# Created On      : Sat Oct 15 23:36:51 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb 23 14:48:23 2006
# Update Count    : 38
# Status          : Unknown, Use with caution!

my $RCS_Id = '$Id: Booking.pm,v 1.6 2006/03/03 21:17:40 jv Exp $ ';

package main;

our $cfg;
our $dbh;
our $spp;
our $config;

package EB::Booking;

use strict;
use warnings;

use EB;
use EB::Finance;

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
	warn("?".__x("De boekingsdatum {date} valt vóór aanvang van dit boekjaar", date => $date)."\n");
	return;
    }
    if ( $date gt $end ) {
	warn("?".__x("De boekingsdatum {date} valt na het einde van dit boekjaar", date => $date)."\n");
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

1;
