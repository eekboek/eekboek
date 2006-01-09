#!/usr/bin/perl -w
my $RCS_Id = '$Id: Open.pm,v 1.10 2006/01/09 17:43:00 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Open;

# Author          : Johan Vromans
# Created On      : Fri Sep 30 17:48:16 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jan  9 16:51:28 2006
# Update Count    : 158
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
      [
	{ name => "rel",  title => _T("Relatie"),      width => 10, },
        { name => "date", title => _T("Datum"),        width => 10, },
	{ name => "desc", title => _T("Omschrijving"), width => 30, },
	{ name => "amt",  title => _T("Bedrag"),       width =>  9, align => ">", },
	{ name => "bsk",  title => _T("Boekstuk"),     width => 16, },
      ];

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{per} = $rep->{periode}->[1];
    $rep->{periodex} = 1;	# force 'per'.

    my $eb = $opts->{eb_handle};

    my $gtot = 0;		# grand total deb/crd
    my $rtot = 0;		# relation total

    my $sth = $dbh->sql_exec("SELECT bsk_id, dbk_id, dbk_desc, bsk_nr, bsk_desc, bsk_date,".
			     " bsk_open, dbk_type, dbk_acc_id, bsr_rel_code, bsk_bky".
			     " FROM Boekstukken, Dagboeken, Boekstukregels".
			     " WHERE bsk_dbk_id = dbk_id".
			     " AND bsr_bsk_id = bsk_id AND bsr_nr = 1".
			     " AND bsk_open IS NOT NULL".
			     " AND bsk_open != 0".
			     " AND dbk_type in (@{[DBKTYPE_INKOOP]},@{[DBKTYPE_VERKOOP]})".
			     ($per ? " AND bsk_date <= ?" : "").
			     " ORDER BY dbk_acc_id, bsr_rel_code, bsk_date",
			     $per ? $per : ());
    unless ( $sth->rows ) {
	$sth->finish;
	return "!"._T("Geen openstaande posten gevonden");
    }

    $rep->start(_T("Openstaande posten"));

    my $cur_rel;
    my $cur_cat;
    my $did;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $dbk_id, $dbk_desc, $bsk_nr, $bsk_desc, $bsk_date,
	    $bsk_amount, $dbk_type, $dbk_acc_id, $bsr_rel, $bsk_bky) = @$rr;
	if ( defined($cur_rel) && $bsr_rel ne $cur_rel ) {
	    $rep->add({ _style => "trelatie",
			desc => __x("Totaal {rel}", rel  => $cur_rel),
			amt  => numfmt($rtot),
		      });
	    $rtot = 0;
	}

	if ( defined($cur_cat) && $dbk_acc_id ne $cur_cat ) {
	    $rep->add({ _style => "tdebcrd",
			desc => __x("Totaal {debcrd}",
				    debcrd => $dbh->lookup($cur_cat, qw(Accounts acc_id acc_desc))),
			amt  => numfmt($gtot),
		      });
	    $gtot = 0;
	}

	$bsk_amount = 0-$bsk_amount if $dbk_type == DBKTYPE_INKOOP;

	if ( $eb ) {
	    my $t = lc($dbk_desc);
	    $t =~ s/\s+/_/g;
	    print {$eb} ("adm_relatie ",
			 join(":", $t, $bsk_bky, $bsk_nr), " ",
			 $bsk_date, " \"", $bsk_desc, "\" \"", $bsr_rel, "\" ",
			 numfmt($bsk_amount), "\n");
	}

	$rep->add({ _style => "data",
		    date => $bsk_date,
		    bsk  => join(":", $dbk_desc, $bsk_nr),
		    desc => $bsk_desc,
		    rel  => $bsr_rel,
		    amt  => numfmt($bsk_amount),
		  });
	$gtot += $bsk_amount;
	$rtot += $bsk_amount;
	$cur_rel = $bsr_rel;
	$cur_cat = $dbk_acc_id;
    }

    if ( defined($cur_rel) ) {
	$rep->add({ _style => "trelatie",
		    desc => __x("Totaal {rel}", rel  => $cur_rel),
		    amt  => numfmt($rtot),
		  });
	$rtot = 0;
    }

    if ( defined($cur_cat) ) {
	$rep->add({ _style => "tdebcrd",
		    desc => __x("Totaal {debcrd}",
				debcrd => $dbh->lookup($cur_cat, qw(Accounts acc_id acc_desc))),
		    amt  => numfmt($gtot),
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
	trelatie  => {
	    _style => { skip_after => 1 },
	},
	tdebcrd  => {
	    _style => { cancel_skip => 1,
			skip_after => 1 },
	    amt    => { line_before => 1 },
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

