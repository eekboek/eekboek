#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grootboek.pm,v 1.23 2006/03/06 15:46:43 jv Exp $ ';

package main;

our $cfg;
our $config;
our $dbh;
our $app;

package EB::Report::Grootboek;

# Author          : Johan Vromans
# Created On      : Wed Jul 27 11:58:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar  6 11:04:32 2006
# Update Count    : 241
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::DB;
use EB::Finance;
use EB::Report::GenBase;
use EB::Report;

################ Subroutines ################

sub new {
    return bless {};
}

sub perform {
    my ($self, $opts) = @_;

    my $detail = $opts->{detail};
    my $sel = $opts->{select};

    $opts->{STYLE} = "grootboek";
    $opts->{LAYOUT} =
      [ { name => "acct", title => _T("GrBk"),               width =>  5, align => ">" },
	{ name => "desc", title => _T("Grootboek/Boekstuk"), width => 30,              },
	{ name => "date", title => _T("Datum"),              width => 10, align => ">" },
	{ name => "deb",  title => _T("Debet"),              width => $amount_width, align => ">" },
	{ name => "crd",  title => _T("Credit"),             width => $amount_width, align => ">" },
	{ name => "bsk",  title => _T("BoekstukNr"),         width => 14,              },
	{ name => "rel",  title => _T("Relatie"),            width => 10,              },
      ];

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{periode};
    my ($begin, $end) = @$per;

    if ( my $t = $cfg->val(qw(internal now), 0) ) {
	$end = $t if $t lt $end;
    }

    $rep->start(_T("Grootboek"));

    my $table = EB::Report->GetTAccountsAll($begin, $end);

    my $ah = $dbh->sql_exec("SELECT acc_id,acc_desc,acc_ibalance,acc_balres".
			    " FROM ${table}".
			    ($sel ?
			     (" WHERE acc_id IN ($sel)") :
			     (" WHERE acc_ibalance <> 0".
			      " OR acc_id in".
			      "  ( SELECT DISTINCT jnl_acc_id FROM Journal )".
		#	      " OR acc_id in".
		#	      "  ( SELECT DISTINCT bkb_acc_id FROM Boekjaarbalans )".
			      " ORDER BY acc_id")));

    my $dgrand = 0;
    my $cgrand = 0;
    my $mdgrand = 0;
    my $mcgrand = 0;
    my $n0 = numfmt(0);

    my $t;
    my $did = 0;

    while ( my $ar = $ah->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $acc_ibalance, $acc_balres) = @$ar;

	my $sth = $dbh->sql_exec("SELECT jnl_amount,jnl_bsk_id,bsk_desc,bsk_nr,dbk_desc,jnl_bsr_date,jnl_desc,jnl_rel".
				 " FROM Journal, Boekstukken, Dagboeken".
				 " WHERE jnl_dbk_id = dbk_id".
				 " AND jnl_bsk_id = bsk_id".
				 " AND jnl_acc_id = ?".
				 " AND jnl_date >= ? AND jnl_date <= ?".
				 " ORDER BY jnl_bsr_date, jnl_bsk_id, jnl_bsr_seq",
				 $acc_id, $begin, $end);

	if ( !$acc_ibalance && !$sth->rows ) {
	    $sth->finish;
	    next;
	}

	$rep->add({ _style => 'h1',
		    acct   => $acc_id,
		    desc   => $acc_desc,
		  }) if $detail;

	my @d = ($n0, $n0);

	if ( $acc_ibalance ) {
	    if ( $acc_ibalance > 0 ) {
		$d[0] = numfmt($acc_ibalance);
	    }
	    else {
		$d[1] = numfmt(-$acc_ibalance);
	    }
	}

	$rep->add({ _style => 'h2',
		    desc   => _T("Beginsaldo"),
		    deb    => $d[0],
		    crd    => $d[1],
		  })
	  if $detail > 0;

	my $dtot = 0;
	my $ctot = 0;
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($amount, $bsk_id, $bsk_desc, $bsk_nr, $dbk_desc, $date, $desc, $rel) = @$rr;

	    if ( $amount < 0 ) {
		$ctot -= $amount;
	    }
	    else {
		$dtot += $amount;
	    }
	    $rep->add({ _style => 'd',
			desc   => $desc,
			date   => $date,
			$amount >= 0 ? ( deb => numfmt($amount), crd => $n0)
				     : ( deb => $n0, crd => numfmt(-$amount)),
			bsk    => join(":", $dbk_desc, $bsk_nr),
			$rel ? ( rel => $rel) : (),
		      }) if $detail > 1;
	}

	$rep->add({ _style => 't2',
		    desc   => _T("Totaal mutaties"),
		    $ctot > $dtot ? ( crd => numfmt($ctot-$dtot) )
				  : ( deb => numfmt($dtot-$ctot) ),
		  })
	  if $detail && ($dtot || $ctot || $acc_ibalance);

	if ( $dtot > $ctot ) {
	    $mdgrand += $dtot - $ctot;
	}
	else {
	    $mcgrand += $ctot - $dtot;
	}

	$rep->add({ _style => 't1',
		    acct   => $acc_id,
		    desc   => __x("Totaal {adesc}", adesc => $acc_desc),
		    $ctot > $dtot + $acc_ibalance ? ( crd => numfmt($ctot-$dtot-$acc_ibalance) )
						  : ( deb => numfmt($dtot+$acc_ibalance-$ctot) ),
		  });
	if ( $ctot > $dtot + $acc_ibalance ) {
	    $cgrand += $ctot - $dtot-$acc_ibalance;
	}
	else {
	    $dgrand += $dtot+$acc_ibalance - $ctot;
	}
	$did++;
    }

    if ( $did ) {
	$rep->add({ _style => 'tm',
		    desc => _T("Totaal mutaties"),
		    deb => numfmt($mdgrand),
		    crd => numfmt($mcgrand),
		  });
	$rep->add({ _style => 'tg',
		    desc   => _T("Totaal"),
		    deb    => numfmt($dgrand),
		    crd    => numfmt($cgrand),
		   });
    }
    else {
	print("?"._T("Geen informatie gevonden")."\n");
    }

    $rep->finish;
    # Rollback temp table.
    $dbh->rollback;
}

package EB::Report::Grootboek::Text;

use EB;
use base qw(EB::Report::Reporter::Text);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
    $self->{detail} = $opts->{detail};
    return $self;
}

# Style mods.

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	_any => {
	#    desc   => { truncate    => 1 },
	},
	h2  => {
	    desc   => { indent      => 1 },
	},
	d  => {
	    desc   => { indent      => 2 },
	},
	t1  => {
	    _style => { skip_after  => ($self->{detail} > 0) },
	},
	t2  => {
	    desc   => { indent      => 1 },
	},
	tm => {
	    _style => { skip_before => 1 },
	},
	tg => {
	    _style => { line_before => 1 }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::Grootboek::Html;

use EB;
use base qw(EB::Report::Reporter::Html);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

package EB::Report::Grootboek::Csv;

use EB;
use base qw(EB::Report::Reporter::Csv);
use strict;

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}


1;
