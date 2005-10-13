#!/usr/bin/perl -w
my $RCS_Id = '$Id: Open.pm,v 1.5 2005/10/13 11:25:44 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Open; 

# Author          : Johan Vromans
# Created On      : Fri Sep 30 17:48:16 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Oct 13 13:24:47 2005
# Update Count    : 80
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::Finance;

################ Subroutines ################

sub new {
    return bless {};
}

sub perform {
    my ($self, $opts) = @_;

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{periode};

    my $sth = $dbh->sql_exec("SELECT bsk_id, dbk_id, dbk_desc, bsk_nr, bsk_desc, bsk_date,".
			     " bsk_open, dbk_type, bsr_rel_code".
			     " FROM Boekstukken, Dagboeken, Boekstukregels".
			     " WHERE bsk_dbk_id = dbk_id".
			     " AND bsr_bsk_id = bsk_id AND bsr_nr = 1".
			     " AND bsk_open IS NOT NULL".
			     " AND bsk_open != 0".
			     " AND dbk_type in (@{[DBKTYPE_INKOOP]},@{[DBKTYPE_VERKOOP]})".
			     ($per ? " AND bsk_date >= ? AND bsk_date <= ?" : "").
			     " ORDER BY dbk_id, bsk_date",
			     $per ? @$per : ());
    unless ( $sth->rows ) {
	$sth->finish;
	return "!"._T("Geen openstaande posten gevonden");
    }

    $rep->start(_T("Openstaande posten"));

    my $cur;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $dbk_id, $dbk_desc, $bsk_nr, $bsk_desc, $bsk_date, $bsk_amount, $dbk_type, $bsr_rel) = @$rr;
	if ( defined($cur) && $cur != $dbk_id ) {
	    $rep->outline(' ');
	}
	$cur = $dbk_id;
	$rep->outline('D', $bsk_date, join(":", $dbk_desc, $bsk_nr), $bsk_desc, $bsr_rel,
		      numfmt($dbk_type == DBKTYPE_INKOOP ? 0-$bsk_amount : $bsk_amount));
    }

    $rep->finish;
    return;
}

package EB::Report::Open::Text;

use EB;
use base qw(EB::Report::GenBase);

my $fmt = "%-10s  %-16s  %-30s  %-10s  %9s\n";

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts);
}

my ($adm, $hdr, $year, $per, $now);
my ($date, $bsk, $desc, $rel, $amt);

sub start {
    my ($self, $text) = @_;
    $hdr = $text;
    $self->{fh}->format_top_name(__PACKAGE__."::ropn0");
    $adm = $dbh->adm("name");
    $year = substr($dbh->adm("begin"), 0, 4);
    my @tm = localtime(time);
    $now = sprintf("%04d-%02d-%02d %02d:%02d",
		   1900+$tm[5], 1+$tm[4], $tm[3], @tm[2,1]);
    if ( $self->{periode} ) {
	$per = __x("Periode: {from} t/m {to}",
		   from => $self->{periode}->[0],
		   to   => $self->{periode}->[1]);
    }
    else {
	$per = '';
    }
}

sub outline {
    my ($self, $type, @args) = @_;

    ($date, $bsk, $desc, $rel, $amt) = ('') x 5;

    if ( $type eq 'D' ) {
	($date, $bsk, $desc, $rel, $amt) = @args;
	$self->{fh}->format_write(__PACKAGE__."::ropn");
	return;
    }

    if ( $type eq ' ' ) {
	$self->{fh}->format_write(__PACKAGE__."::ropn");
	return;
    }

    die("?".__x("Programmafout: verkeerd type in {here}",
		here => __PACKAGE__ . "::_repline")."\n");
}

sub finish {
    my ($self) = @_;
    $self->{fh}->format_write(__PACKAGE__."::ropnx");
    $self->{fh}->close;
}

format ropn0 =
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$hdr
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>
$per, ''
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $now . ' ' . $EB::ident

@<<<<<<<<<  @<<<<<<<<<<<<<<<  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<  @>>>>>>>>
_T("Datum"), _T("Boekstuk"), _T("Omschrijving"), _T("Relatie"), _T("Bedrag")
-----------------------------------------------------------------------------------
.
format ropnx =
-----------------------------------------------------------------------------------
.
format ropn =
@<<<<<<<<<  @<<<<<<<<<<<<<<<  ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @<<<<<<<<<  @>>>>>>>>
$date, $bsk, $desc, $rel, $amt
~~                            ^<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.

1;
