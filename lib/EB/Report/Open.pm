#!/usr/bin/perl -w
my $RCS_Id = '$Id: Open.pm,v 1.3 2005/10/10 20:17:19 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Open; 

# Author          : Johan Vromans
# Created On      : Fri Sep 30 17:48:16 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Oct 10 18:29:38 2005
# Update Count    : 46
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
    $rep->start;

    my $sth = $dbh->sql_exec("SELECT bsk_id, dbk_desc, bsk_nr, bsk_desc, bsk_date,".
			     " bsk_open, dbk_type, bsr_rel_code".
			     " FROM Boekstukken, Dagboeken, Boekstukregels".
			     " WHERE bsk_dbk_id = dbk_id".
			     " AND bsr_bsk_id = bsk_id AND bsr_nr = 1".
			     " AND bsk_open IS NOT NULL".
			     " AND bsk_open != 0".
			     " AND dbk_type in (@{[DBKTYPE_INKOOP]},@{[DBKTYPE_VERKOOP]})");
    unless ( $sth->rows ) {
	$sth->finish;
	return "!"._T("Geen openstaande posten gevonden");
    }

    my @tm = localtime(time);
    $rep->outline('H','','',
		  __x("Openstaande posten d.d. {date}",
		      date => sprintf("%04d-%02d-%02d", 1900+$tm[5], 1+$tm[4], $tm[3])),
		  '','');

    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $dbk_desc, $bsk_nr, $bsk_desc, $bsk_date, $bsk_amount, $dbk_type, $bsr_rel) = @$rr;
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

my $hdr;

my ($date, $bsk, $desc, $rel, $amt);

sub start {
    my $self = shift;
    $^ = 'ropn0';
    $~ = 'ropn';
}

sub outline {
    my ($self, $type, @args) = @_;

    $self->{did}++;

    ($date, $bsk, $desc, $rel, $amt) = ('') x 5;

    if ( $type eq 'H' ) {
	($desc) = @args;
	write;
	return;
    }

    if ( $type eq 'D' ) {
	($date, $bsk, $desc, $rel, $amt) = @args;
	write;
	return;
    }

    die("?".__x("Programmafout: verkeerd type in {here}",
		here => __PACKAGE__ . "::_repline")."\n");
}

sub finish {
    my ($self) = @_;
    print('-'x83, "\n") if $self->{did};
}

format ropn0 =
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc

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

1;
