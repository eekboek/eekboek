#!/usr/bin/perl -w
my $RCS_Id = '$Id: Journal.pm,v 1.27 2006/01/22 16:42:24 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Jan 22 15:52:30 2006
# Update Count    : 270
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;
our $dbh;

package EB::Report::Journal;

use strict;
use warnings;

use EB;
use EB::Finance;
use EB::DB;
use EB::Report::GenBase;

sub new {
    bless {};
}

sub journal {
    my ($self, $opts) = @_;

    my $nr = $opts->{select};
    my $pfx = $opts->{postfix} || "";
    my $detail = $opts->{detail};

    $opts->{STYLE} = "journaal";
    $opts->{LAYOUT} =
      [ { name => "date", title => _T("Datum"),              width => 10, },
	{ name => "desc", title => _T("Boekstuk/Grootboek"), width => 30, },
	{ name => "acct", title => _T("Rek"),                width =>  5, align => ">", },
	{ name => "deb",  title => _T("Debet"),              width =>  9, align => ">", },
	{ name => "crd",  title => _T("Credit"),             width =>  9, align => ">", },
	{ name => "bsk",  title => _T("Boekstuk/regel"),     width => 30, },
	{ name => "rel",  title => _T("Relatie"),            width => 10, },
      ];

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{periode};
    if ( my $t = $cfg->val(qw(internal now), 0) ) {
	$per->[1] = $t if $t lt $per->[1];
    }
    $rep->start(_T("Journaal"));

    my $sth;
    if ( $nr ) {
	if ( $nr =~ /^([[:alpha:]].*):(\d+)$/ ) {
	    my $rr = $dbh->do("SELECT dbk_desc, dbk_id".
			      " FROM Dagboeken".
			      " WHERE dbk_desc ILIKE ?",
			      $1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				  "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				  " FROM Journal, Boekstukken, Dagboeken".
				  " WHERE bsk_nr = ?".
				  " AND dbk_id = ?".
				  " AND jnl_bsk_id = bsk_id".
				  " AND jnl_dbk_id = dbk_id".
				  ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				  " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				  $2, $rr->[1], $per ? @$per : ());
	    $pfx ||= __x("Boekstuk {nr}", nr => "$rr->[0]:$2");
	}
	elsif ( $nr =~ /^([[:alpha:]].*)$/ ) {
	    my $rr = $dbh->do("SELECT dbk_desc, dbk_id".
			      " FROM Dagboeken".
			      " WHERE dbk_desc ILIKE ?",
			      $1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				  "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				  " FROM Journal, Boekstukken, Dagboeken".
				  " WHERE dbk_id = ?".
				  " AND jnl_bsk_id = bsk_id".
				  " AND jnl_dbk_id = dbk_id".
				  ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				  " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				  $rr->[1], $per ? @$per : ());
	    $pfx ||= __x("Dagboek {nr}", nr => $rr->[0]);
	}
	else {
	    $sth = $dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				  "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				  " FROM Journal, Boekstukken".
				  " WHERE jnl_bsk_id = ?".
				  " AND jnl_bsk_id = bsk_id".
				  ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				  " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, jnl_amount DESC, jnl_bsr_seq",
				  $nr, $per ? @$per : ());
	    $pfx ||= __x("Boekstuk {nr}", nr => $nr);
	}
    }
    else {
	$sth = $dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
			      "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
			      " FROM Journal, Boekstukken".
			      " WHERE jnl_bsk_id = bsk_id".
			      ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
			      " ORDER BY jnl_date, jnl_dbk_id, bsk_nr, sign(jnl_amount) DESC, jnl_acc_id, jnl_bsr_seq",
			      $per ? @$per : ());
    }
    my $rr;
    my $nl = 0;
    my $totd = my $totc = 0;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($jnl_date, $jnl_bsr_date, $jnl_dbk_id, $jnl_bsk_id, $bsk_nr, $jnl_bsr_seq, $jnl_acc_id,
	    $jnl_amount, $jnl_desc, $jnl_rel) = @$rr;

	if ( $jnl_bsr_seq == 0 ) {
	    $nl++, next unless $detail;
	    $rep->add({ _style => 'head',
			date => $jnl_bsr_date,
			desc => join(":", _dbk_desc($jnl_dbk_id), $bsk_nr),
			bsk  => $jnl_desc,
		      });
	    next;
	}

	$totd += $jnl_amount if $jnl_amount > 0;
	$totc -= $jnl_amount if $jnl_amount < 0;
	next unless $detail;
	$rep->add({ _style => 'data',
		    date => $jnl_bsr_date,
		    desc => _acc_desc($jnl_acc_id),
		    acct => $jnl_acc_id,
		    $jnl_amount >= 0 ? ( deb => numfmt($jnl_amount) )
				     : ( crd => numfmt(-$jnl_amount) ),
		    bsk  => $jnl_desc,
		    $jnl_rel ? ( rel => $jnl_rel ) : (),
		  });
    }
    $rep->add({ _style => 'total',
		desc => __x("Totaal {pfx}", pfx => $pfx),
		deb  => numfmt($totd),
		crd  => numfmt($totc),
	      });
    $rep->finish;
}

my %dbk_desc;
sub _dbk_desc {
    $dbk_desc{$_[0]} ||= $dbh->lookup($_[0],
				      qw(Dagboeken dbk_id dbk_desc =));
}

my %acc_desc;
sub _acc_desc {
    return '' unless $_[0];
    $acc_desc{$_[0]} ||= $dbh->lookup($_[0],
				      qw(Accounts acc_id acc_desc =));
}

package EB::Report::Journal::Text;

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
	data  => {
	    _style => { skip_after  => 1,
			cancel_skip => 1,
		      },
	    desc   => { indent      => 2 },
	    bsk    => { indent      => 2 },
	},
	total => {
	    _style => { line_before => 1 },
	    desc   => { excess      => 1 },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::Journal::Html;

use EB;
use base qw(EB::Report::Reporter::Html);
use strict;

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

package EB::Report::Journal::Csv;

use EB;
use base qw(EB::Report::Reporter::Csv);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

1;

