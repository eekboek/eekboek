#!/usr/bin/perl -w
my $RCS_Id = '$Id: Journal.pm,v 1.9 2005/09/21 13:09:01 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 21 14:58:18 2005
# Update Count    : 147
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Journal::Text;

use strict;
use warnings;

use EB;
use EB::Finance;
use EB::DB;

sub new {
    bless {};
}

use locale;

my $repfmt = "%-10s  %3s  %-4s  %-30.30s  %5s  %9s  %9s  %-30.30s  %s\n";

sub journal {
    my ($self, $opts) = @_;

    my $nr = $opts->{select};
    my $pfx = $opts->{postfix} || "";
    my $detail = $opts->{detail};

    my $sth;
    if ( $nr ) {
	if ( $nr =~ /^([[:alpha:]].+):(\d+)$/ ) {
	    my $rr = $::dbh->do("SELECT dbk_desc, dbk_id".
				" FROM Dagboeken".
				" WHERE dbk_desc ILIKE ?",
				$1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken, Dagboeken".
				    " WHERE bsk_nr = ?".
				    " AND dbk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    " AND jnl_dbk_id = dbk_id".
				    " ORDER BY jnl_date, jnl_dbk_id, jnl_amount DESC, jnl_bsk_id, jnl_bsr_seq",
				    $2, $rr->[1]);
	    $pfx ||= __x("Boekstuk {nr}", nr => "$rr->[0]:$2");
	}
	elsif ( $nr =~ /^([[:alpha:]].+)$/ ) {
	    my $rr = $::dbh->do("SELECT dbk_desc, dbk_id".
				" FROM Dagboeken".
				" WHERE dbk_desc ILIKE ?",
				$1);
	    unless ( $rr ) {
		warn("?".__x("Onbekend dagboek: {dbk}", dbk => $1)."\n");
		return;
	    }
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken, Dagboeken".
				    " WHERE dbk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    " AND jnl_dbk_id = dbk_id".
				    " ORDER BY jnl_date, jnl_dbk_id, jnl_amount DESC, jnl_bsk_id, jnl_bsr_seq",
				    $rr->[1]);
	    $pfx ||= __x("Dagboek {nr}", nr => $rr->[0]);
	}
	else {
	    $sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				    "jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				    " FROM Journal, Boekstukken".
				    " WHERE jnl_bsk_id = ?".
				    " AND jnl_bsk_id = bsk_id".
				    " ORDER BY jnl_date, jnl_dbk_id, jnl_amount DESC, jnl_bsk_id, jnl_bsr_seq",
				    $nr);
	    $pfx ||= __x("Boekstuk {nr}", nr => $nr);
	}
    }
    else {
	$sth = $::dbh->sql_exec("SELECT jnl_date, jnl_bsr_date, jnl_dbk_id, jnl_bsk_id, bsk_nr, jnl_bsr_seq, ".
				"jnl_acc_id, jnl_amount, jnl_desc, jnl_rel".
				" FROM Journal, Boekstukken".
				" WHERE jnl_bsk_id = bsk_id".
				" ORDER BY jnl_date, jnl_dbk_id, jnl_bsk_id, sign(jnl_amount) DESC, jnl_acc_id, jnl_bsr_seq");
    }
    my $rr;
    my $nl = 0;
    my $totd = my $totc = 0;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($jnl_date, $jnl_bsr_date, $jnl_dbk_id, $jnl_bsk_id, $bsk_nr, $jnl_bsr_seq, $jnl_acc_id,
	    $jnl_amount, $jnl_desc, $jnl_rel) = @$rr;

	if ( $jnl_bsr_seq == 0 ) {
	    printf($repfmt,
		   _T("Datum"), _T("Id"), _T("Nr"), _T("Dag/Grootboek"),
		   _T("Rek"), _T("Debet"), _T("Credit"), _T("Boekstuk/regel"),
		   _T("Relatie")) unless $nl;
	    $nl++, next unless $detail;
	    print("\n") if $nl++;
	    $self->_repline($jnl_bsr_date, $jnl_bsk_id, $bsk_nr, _dbk_desc($jnl_dbk_id), '',
			    '', '', $jnl_desc);
	    next;
	}

	$totd += $jnl_amount if $jnl_amount > 0;
	$totc -= $jnl_amount if $jnl_amount < 0;
	next unless $detail;
	$self->_repline($jnl_bsr_date, '', '', "  "._acc_desc($jnl_acc_id),
			$jnl_acc_id, numdebcrd($jnl_amount), "  ".$jnl_desc, $jnl_rel);
    }
    $self->_repline('', '', '', __x("Totaal {pfx}", pfx => $pfx), '', $totd, $totc);
}

sub _repline {
    my ($self, $date, $bsk, $nr, $loc, $acc, $deb, $crd, $desc, $rel) = (@_, ('') x 7);
    for ( $deb, $crd ) {
	$_ = $_ ? numfmt($_) : '';
    }
    printf($repfmt,
	   $date, $bsk, $nr, $loc, $acc, $deb, $crd, $desc, $rel || '');
}

my %dbk_desc;
sub _dbk_desc {
    $dbk_desc{$_[0]} ||= $::dbh->lookup($_[0],
				      qw(Dagboeken dbk_id dbk_desc =));
}

my %acc_desc;
sub _acc_desc {
    return '' unless $_[0];
    $acc_desc{$_[0]} ||= $::dbh->lookup($_[0],
				      qw(Accounts acc_id acc_desc =));
}

1;
