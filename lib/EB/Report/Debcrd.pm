#!/usr/bin/perl -w
my $RCS_Id = '$Id: Debcrd.pm,v 1.6 2006/01/05 17:59:53 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Debcrd;

# Author          : Johan Vromans
# Created On      : Wed Dec 28 16:08:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jan  5 18:40:47 2006
# Update Count    : 118
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::Finance;
use EB::Report::GenBase;

################ Subroutines ################

sub new {
    return bless {};
}

sub debiteuren {
    my ($self, $args, $opts) = @_;
    $self->_perform($args, $opts, 1);
}

sub crediteuren {
    my ($self, $args, $opts) = @_;
    $self->_perform($args, $opts, 0);
}

sub _perform {
    my ($self, $args, $opts, $debcrd) = @_;

    $args = uc(join("|", @$args)) if $args;

    $opts->{STYLE} = "debrept";
    $opts->{LAYOUT} =
      [ { name  => "debcrd",
	  title => $debcrd ? _T("Debiteur") : _T("Crediteur"),
	  width => 10 },
	{ name  => "date",   title => _T("Datum"),        width => 10 },
	{ name  => "desc",   title => _T("Omschrijving"), width => 25 },
	{ name  => "amount", title => _T("Bedrag"),       width => 10, align => ">" },
	{ name  => "open",   title => _T("Openstaand"),   width => 10, align => ">" },
	{ name  => "paid",   title => _T("Betaald"),      width => 10, align => ">" },
	{ name  => "bsknr",  title => _T("Boekstuk"),     width => 13 },
      ];

    my $rep = EB::Report::GenBase->backend($self, { %$opts, debcrd => $debcrd });

    my $sth = $dbh->sql_exec("SELECT DISTINCT bsr_rel_code".
			     " FROM Boekstukregels, Boekstukken, Dagboeken".
			     " WHERE bsr_date >= ? AND bsr_date <= ?".
			     " AND bsr_bsk_id = bsk_id".
			     " AND bsk_dbk_id = dbk_id".
			     " AND dbk_type = ?".
			     ($args ? " AND bsr_rel_code IN (?)" : "").
			     " ORDER BY bsr_rel_code",
			     @{$rep->{periode}},
			     $debcrd ? DBKTYPE_VERKOOP : DBKTYPE_INKOOP,
			     $args ? $args : ());

    my @rels;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	push(@rels, $rr->[0]);
    }
    $sth->finish;
    return "!"._T("Geen boekingen gevonden") unless @rels;

    $rep->start($debcrd ? _T("Debiteurenadministratie")
	                : _T("Crediteurenadministratie"));

    my $a_grand = 0;
    my $o_grand = 0;

    foreach my $rel ( @rels ) {

	my $a_tot = 0;
	my $o_tot = 0;

	my $sth = $dbh->sql_exec("SELECT bsk_id, bsk_desc, bsk_date,".
				 " bsk_amount, bsk_open, dbk_desc, bsk_nr".
				 " FROM Boekstukken, Boekstukregels, Dagboeken".
				 " WHERE bsr_date >= ? AND bsr_date <= ?".
				 " AND bsr_bsk_id = bsk_id".
				 " AND bsk_dbk_id = dbk_id".
				 " AND bsr_type = 0".
				 " AND bsr_nr = 1".
				 " AND bsr_rel_code = ?".
				 " ORDER BY bsk_date",
				 @{$rep->{periode}},
				 $rel);

	$rep->add({ debcrd => $rel, _style=> "h1" });

	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($bsk_id, $bsk_desc, $bsk_date,
		$bsr_amount, $bsr_open, $dbk_desc, $bsk_nr) = @$rr;
	    $bsr_amount = 0-$bsr_amount unless $debcrd;
	    $bsr_open = 0-$bsr_open unless $debcrd;

	    $rep->add({ desc   => $bsk_desc,
			date   => $bsk_date,
			amount => numfmt($bsr_amount),
			open   => numfmt($bsr_open),
			bsknr  => join(":", $dbk_desc, $bsk_nr),
			_style => "bsk",
		      });
	    $a_tot += $bsr_amount;
	    $o_tot += $bsr_open;
	    my $sth = $dbh->sql_exec("SELECT bsr_date, bsr_desc, bsr_amount,".
				     " dbk_desc, bsk_nr".
				     " FROM Boekstukregels, Boekstukken, Dagboeken".
				     " WHERE bsr_type = ?".
				     " AND bsr_paid = ?".
				     " AND bsr_bsk_id = bsk_id AND bsk_dbk_id = dbk_id".
				     " ORDER BY bsr_date",
				     $debcrd ? 1 : 2, $bsk_id);
	    while ( my $rr = $sth->fetchrow_arrayref ) {
		my ($x_bsr_date, $x_bsr_desc, $x_bsr_amount,
		    $x_dbk_desc, $x_bsk_nr) = @$rr;
		$x_bsr_amount = 0-$x_bsr_amount unless $debcrd;
		$rep->add({ desc    => $x_bsr_desc,
			    date    => $x_bsr_date,
			    paid    => numfmt(0-$x_bsr_amount),
			    bsknr   => join(":", $x_dbk_desc, $x_bsk_nr),
			    _style  => "paid",
			  });
	    }
	}

	$rep->add({ debcrd => $rel,
		    desc   => _T("Totaal"),
		    amount => numfmt($a_tot),
		    open   => numfmt($o_tot),
		    _style => "total",
		  });

	$a_grand += $a_tot;
	$o_grand += $o_tot;
    }

    $rep->add({ debcrd => _T("Totaal"),
		amount => numfmt($a_grand),
		open   => numfmt($o_grand),
		_style => "grand",
	      });

    $rep->finish;
    return;
}

package EB::Report::Debcrd::Text;

use EB;
use base qw(EB::Report::Reporter::Text);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

# Style mods.

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	paid  => {
	    desc   => { indent      => 2 },
	},
	total => {
	    _style => { skip_after  => 1 },
	    amount => { line_before => 1 },
	    open   => { line_before => 1 },
	},
	grand => {
	    _style => { line_before => 1 }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::Debcrd::Html;

use EB;
use base qw(EB::Report::Reporter::Html);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

package EB::Report::Debcrd::Csv;

use EB;
use base qw(EB::Report::Reporter::Csv);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

1;
