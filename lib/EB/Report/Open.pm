#!/usr/bin/perl -w
my $RCS_Id = '$Id: Open.pm,v 1.9 2006/01/05 17:59:53 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Open;

# Author          : Johan Vromans
# Created On      : Fri Sep 30 17:48:16 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jan  5 18:53:08 2006
# Update Count    : 110
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

    $opts->{STYLE} = "openstaand";
    $opts->{LAYOUT} =
      [ { name => "date", title => _T("Datum"),        width => 10, },
	{ name => "bsk",  title => _T("Boekstuk"),     width => 16, },
	{ name => "desc", title => _T("Omschrijving"), width => 30, },
	{ name => "rel",  title => _T("Relatie"),      width => 10, },
	{ name => "amt",  title => _T("Bedrag"),       width =>  9, align => ">", },
      ];

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{per} = $rep->{periode}->[1];
    $rep->{periodex} = 1;	# force 'per'.

    my $sth = $dbh->sql_exec("SELECT bsk_id, dbk_id, dbk_desc, bsk_nr, bsk_desc, bsk_date,".
			     " bsk_open, dbk_type, bsr_rel_code".
			     " FROM Boekstukken, Dagboeken, Boekstukregels".
			     " WHERE bsk_dbk_id = dbk_id".
			     " AND bsr_bsk_id = bsk_id AND bsr_nr = 1".
			     " AND bsk_open IS NOT NULL".
			     " AND bsk_open != 0".
			     " AND dbk_type in (@{[DBKTYPE_INKOOP]},@{[DBKTYPE_VERKOOP]})".
			     ($per ? " AND bsk_date <= ?" : "").
			     " ORDER BY dbk_id, bsk_date",
			     $per ? $per : ());
    unless ( $sth->rows ) {
	$sth->finish;
	return "!"._T("Geen openstaande posten gevonden");
    }

    $rep->start(_T("Openstaande posten"));

    my $cur;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $dbk_id, $dbk_desc, $bsk_nr, $bsk_desc, $bsk_date, $bsk_amount, $dbk_type, $bsr_rel) = @$rr;
	my $style = "data";
	if ( defined($cur) && $cur != $dbk_id ) {
	    $style = "first";
	}
	$cur = $dbk_id;
	$rep->add({ _style => $style,
		    date => $bsk_date,
		    bsk  => join(":", $dbk_desc, $bsk_nr),
		    desc => $bsk_desc,
		    rel  => $bsr_rel,
		    amt  => numfmt($dbk_type == DBKTYPE_INKOOP ? 0-$bsk_amount : $bsk_amount),
		  });
    }

    $rep->add({ _style => "last" });
    $rep->finish;
    return;
}

package EB::Report::Open::Text;

use EB;
use base qw(EB::Report::Reporter::Text);
use strict;

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

# Style mods.

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	first  => {
	    _style => { skip_before => 1 },
	},
	last   => {
	    _style => { line_before => 1 },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::Open::Html;

use EB;
use base qw(EB::Report::Reporter::Html);
use strict;

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

package EB::Report::Open::Csv;

use EB;
use base qw(EB::Report::Reporter::Csv);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

1;

