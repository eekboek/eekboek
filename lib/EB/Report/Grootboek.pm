#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grootboek.pm,v 1.13 2005/10/15 18:45:40 jv Exp $ ';

package main;

our $config;
our $dbh;
our $app;

package EB::Report::Grootboek;

# Author          : Johan Vromans
# Created On      : Wed Jul 27 11:58:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct 15 20:44:58 2005
# Update Count    : 139
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::DB;
use EB::Finance;
use EB::Report::GenBase;

################ Subroutines ################

sub new {
    return bless {};
}

my $did;

sub perform {
    my ($self, $opts) = @_;

    my $detail = $opts->{detail};
    my $sel = $opts->{select};
    my $per = $opts->{periode};

    my $rep = EB::Report::GenBase->backend($self, $opts);
    $rep->start;

    my $date = $dbh->adm("begin");
    my $now = $ENV{EB_SQL_NOW} || iso8601date();

    print(_T("Grootboek"), " -- ",
	  __x("Periode {from} - {to}",
	      from => $date, to => substr($now,0,10)), "\n\n");

    my $ah = $dbh->sql_exec("SELECT acc_id,acc_desc,acc_ibalance".
			    " FROM Accounts".
			    ($sel ?
			     (" WHERE acc_id IN ($sel)") :
			     (" WHERE acc_ibalance <> 0".
			      " OR acc_id in".
			      "  ( SELECT DISTINCT jnl_acc_id FROM Journal )".
			      " ORDER BY acc_id")));

    my $dgrand = 0;
    my $cgrand = 0;
    my $mdgrand = 0;
    my $mcgrand = 0;
    my $n0 = numfmt(0);

    my $t;
    $did = 0;

    while ( my $ar = $ah->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $acc_ibalance) = @$ar;

	my $sth = $dbh->sql_exec("SELECT jnl_amount,jnl_bsk_id,bsk_desc,bsk_nr,dbk_desc,jnl_bsr_date,jnl_desc,jnl_rel".
				 " FROM journal, Boekstukken, Dagboeken".
				 " WHERE jnl_dbk_id = dbk_id".
				 " AND jnl_bsk_id = bsk_id".
				 " AND jnl_acc_id = ?".
				 ($per ? " AND jnl_date >= ? AND jnl_date <= ?" : "").
				 " ORDER BY jnl_bsr_date, jnl_bsk_id, jnl_bsr_seq",
				 $acc_id, $per ? @$per : ());

	if ( $per && !$sth->rows ) {
	    $sth->finish;
	    next;
	}

	if ( $did ) {
	    $rep->outline(' ') if $detail;
	}
	$rep->outline('H1', $acc_id, $acc_desc) if $detail;

	my @d = ($n0, $n0);
	$acc_ibalance = 0 if $per;
	if ( $acc_ibalance ) {
	    if ( $acc_ibalance > 0 ) {
		$d[0] = numfmt($acc_ibalance);
	    }
	    else {
		$d[1] = numfmt(-$acc_ibalance);
	    }
	}

	$rep->outline('H2', _T("Beginsaldo"), @d)
	  if $detail > 0 && !$per;

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
	    $rep->outline('D', $desc, $bsk_id, $date,
			  $amount >= 0 ? (numfmt($amount), $n0) : ($n0, numfmt(-$amount)),
			  $dbk_desc, $bsk_nr, $rel||"") if $detail > 1;
	}

	$rep->outline('T2', _T("Totaal mutaties"),
		      $ctot > $dtot ? ("", numfmt($ctot-$dtot)) : (numfmt($dtot-$ctot), ""))
	  if $detail && ($dtot || $ctot || $acc_ibalance);

	if ( $dtot > $ctot ) {
	    $mdgrand += $dtot - $ctot;
	}
	else {
	    $mcgrand += $ctot - $dtot;
	}

	$rep->outline('T1', $acc_id, __x("Totaal {adesc}", adesc => $acc_desc),
		      $ctot > $dtot + $acc_ibalance ? ("", numfmt($ctot-$dtot-$acc_ibalance)) : (numfmt($dtot+$acc_ibalance-$ctot),""));
	if ( $ctot > $dtot + $acc_ibalance ) {
	    $cgrand += $ctot - $dtot-$acc_ibalance;
	}
	else {
	    $dgrand += $dtot+$acc_ibalance - $ctot;
	}
    }

    if ( $did ) {
	$rep->outline('TM', _T("Totaal mutaties"), numfmt($mdgrand), numfmt($mcgrand));
	$rep->outline('TG', _T("Totaal"), numfmt($dgrand), numfmt($cgrand));
    }
    else {
	print("?"._T("Geen informatie gevonden")."\n");
    }

}

package EB::Report::Grootboek::Text;

use strict;
use EB;
use base qw(EB::Report::GenBase);

my ($gbk, $desc, $id, $date, $deb, $crd, $dbk, $nr, $rel);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

sub start {
    my ($self) = @_;
    $self->{fh}->format_top_name('gbkfmt0');
    $self;
}

sub outline {
    my ($self, $type, @args) = @_;

    ($gbk, $desc, $id, $date, $deb, $crd, $dbk, $nr, $rel) = ('') x 9;
    $did++;

    if ( $type eq 'H1' ) {
	($gbk, $desc) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	return;
    }

    if ( $type eq 'H2' ) {
	($desc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt2');
	return;
    }

    if ( $type eq 'D' ) {
	($desc, $id, $date, $deb, $crd, $dbk, $nr, $rel) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt3');
	return;
    }

    if ( $type eq 'T2' ) {
	($desc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt2');
	return;
    }

    if ( $type eq 'T1' ) {
	($gbk, $desc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	return;
    }

    if ( $type eq 'TM' ) {
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	($desc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	return;
    }

    if ( $type eq 'TG' ) {
	($desc, $deb, $crd) = @args;
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmtl');
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	return;
    }

    if ( $type eq ' ' ) {
	$self->{fh}->format_write(__PACKAGE__.'::gbkfmt1');
	return;
    }

    die("?".__x("Programmafout: verkeerd type in {here}",
		here => __PACKAGE__ . "::_repline")."\n");
}

sub finish {
    my ($self) = @_;
    $self->{fh}->close;
}

format gbkfmt0 =
@>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<  @>>>  @<<<<<<<<<
_T("GrBk"), _T("Grootboek/Boekstuk"), _T("Id"), _T("Datum"), _T("Debet"), _T("Credit"), _T("Dagboek"), _T("Nr"), _T("Relatie")
-------------------------------------------------------------------------------------------------@<<<<<<<<<
"-" x length(_T("Relatie"))
.

format gbkfmtl =
-------------------------------------------------------------------------------------------------@<<<<<<<<<
"-" x length(_T("Relatie"))
.

format gbkfmt1 =
@>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<  @<<<  @<<<<<<<<<
$gbk, $desc, $id, $date, $deb, $crd, $dbk, $nr, $rel
.

format gbkfmt2 =
        @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<                  @>>>>>>>>> @>>>>>>>>>
$desc, $deb, $crd
.

format gbkfmt3 =
         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<  @<<<  @<<<<<<<<<
$desc, $id, $date, $deb, $crd, $dbk, $nr, $rel
~~       ^<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.

1;
