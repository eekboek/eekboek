#!/usr/bin/perl -w
my $RCS_Id = '$Id: Open.pm,v 1.1 2005/09/30 16:40:15 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Open; 

# Author          : Johan Vromans
# Created On      : Fri Sep 30 17:48:16 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Sep 30 18:31:45 2005
# Update Count    : 32
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

    my $rep = $opts->{reporter} || EB::Report::Open::Text->new($opts);

    my $sth = $dbh->sql_exec("SELECT bsk_id, dbk_desc, bsk_nr, bsk_desc, bsk_date,".
			     " bsk_amount, dbk_type, bsr_rel_code".
			     " FROM Boekstukken, Dagboeken, Boekstukregels".
			     " WHERE bsk_dbk_id = dbk_id".
			     " AND bsr_bsk_id = bsk_id AND bsr_nr = 1".
			     " AND bsk_paid IS NULL".
			     " AND dbk_type in (@{[DBKTYPE_INKOOP]},@{[DBKTYPE_VERKOOP]})");
    unless ( $sth->rows ) {
	$sth->finish;
	return "!"._T("Geen openstaande posten gevonden");
    }

    my @tm = localtime(time);
    $rep->addline('H','','',
		  __x("Openstaande posten d.d. {date}",
		      date => sprintf("%04d-%02d-%02d", 1900+$tm[5], 1+$tm[4], $tm[3])),
		  '','');

    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $dbk_desc, $bsk_nr, $bsk_desc, $bsk_date, $bsk_amount, $dbk_type, $bsr_rel) = @$rr;
	$rep->addline('D', $bsk_date, join(":", $dbk_desc, $bsk_nr), $bsk_desc, $bsr_rel,
		      numfmt($dbk_type == DBKTYPE_INKOOP ? 0-$bsk_amount : $bsk_amount));
    }

    $rep->finish;
    return;
}

package EB::Report::Open::Text;

use EB;

my $fmt = "%-10s  %-16s  %-30s  %-10s  %9s\n";

sub new {
    return bless {};
}

my $hdr;

sub addline {
    my ($self, $type, $date, $bsk, $desc, $rel, $amt) = @_;

    if ( $type eq 'H' ) {
	print($desc, "\n\n");
	return;
    }

    my $line;
    unless ( $self->{hdr} ) {
	my $hdr = sprintf($fmt, _T("Datum"), _T("Boekstuk"),
			  _T("Omschrijving"), _T("Relatie"), _T("Bedrag"));
	$hdr =~ s/ +$//;
	print($hdr);
	$hdr =~ tr/\n/_/c;
	print($hdr);
	$self->{hdr} = $hdr;
    }

    if ( $type eq 'D' ) {
	$line = sprintf($fmt, $date, $bsk, $desc, $rel, $amt);
    }
    $line =~ s/^ +$//;
    print($line);
}

sub finish {
    my ($self) = @_;
    print($self->{hdr}) if $self->{hdr};
}

1;
