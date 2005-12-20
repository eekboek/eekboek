#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grootboek.pm,v 1.17 2005/12/20 20:47:54 jv Exp $ ';

package main;

our $config;
our $dbh;
our $app;

package EB::Report::Grootboek;

# Author          : Johan Vromans
# Created On      : Wed Jul 27 11:58:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Dec 17 16:24:12 2005
# Update Count    : 207
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

    my $rep = EB::Report::GenBase->backend($self, $opts);
    my $per = $rep->{periode};
    my ($begin, $end) = @$per;

    $end = $ENV{EB_SQL_NOW} if $ENV{EB_SQL_NOW} && $end gt $ENV{EB_SQL_NOW};

    $rep->start(_T("Grootboek"),
		__x("Periode: {from} t/m {to}",
		    from => $begin, to => $end));

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

=begin nono

    # Real (absolute) beginning of admin data.
    my $admbegin = parse_date($dbh->lookup(BKY_PREVIOUS, qw(Boekjaren bky_code bky_end)), undef, 1);

    # Beginning of open admin data.
    my $opnbegin = parse_date($dbh->do("SELECT bky_end".
				       " FROM Boekjaren".
				       " WHERE bky_closed IS NOT NULL".
				       " AND bky_end < ?".
				       " ORDER BY bky_begin DESC",
				       $begin)->[0], undef, 1);

=cut

    while ( my $ar = $ah->fetchrow_arrayref ) {
	my ($acc_id, $acc_desc, $acc_ibalance, $acc_balres) = @$ar;

=begin nono

	# Fix initial balance.
	if ( $admbegin ne $begin ) {
	    #warn("=> fixing acc $acc_id\n");
	    if ( $opnbegin ne $admbegin ) {
		if ( $acc_balres ) {
		    my $t = $dbh->do("SELECT bkb_balance".
				     " FROM Boekjaarbalans".
				     " WHERE bkb_acc_id = ?".
				     " AND bkb_end < ?".
				     " ORDER BY bkb_end DESC",
				     $acc_id, $begin);
		    if ( $t ) {
			#warn("=> balance for acc $acc_id adj ".numfmt($acc_ibalance)." to ".numfmt($acc_ibalance-$t->[0])."\n");
			$acc_ibalance -= $t->[0];
		    }
		    $t = $dbh->do("SELECT SUM(jnl_amount)".
				  " FROM Journal".
				  " WHERE jnl_acc_id = ?".
				  " AND jnl_date < ? AND jnl_date >= ?",
				  $acc_id, $begin, $admbegin);
		    if ( $t && $t->[0] ) {
			#warn("=> balance for acc $acc_id adj ".numfmt($acc_ibalance)." to ".numfmt($acc_ibalance+$t->[0])."\n");
			$acc_ibalance += $t->[0];
		    }
		}
		else {
		    $acc_ibalance = 0;
		}
	    }
	    my $t = $dbh->do("SELECT SUM(jnl_amount)".
			     " FROM Journal".
			     " WHERE jnl_acc_id = ?".
			     " AND jnl_date < ? AND jnl_date >= ?",
			     $acc_id, $begin, $opnbegin);
	    if ( $t && $t->[0] ) {
		$acc_ibalance += $t->[0];
		#warn("=> balance for acc $acc_id adj to ".numfmt($acc_ibalance)."\n");
	    }
	}

=cut

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

	if ( $did ) {
	    $rep->outline(' ') if $detail;
	}
	$rep->outline('H1', $acc_id, $acc_desc) if $detail;

	my @d = ($n0, $n0);

	if ( $acc_ibalance ) {
	    if ( $acc_ibalance > 0 ) {
		$d[0] = numfmt($acc_ibalance);
	    }
	    else {
		$d[1] = numfmt(-$acc_ibalance);
	    }
	}

	$rep->outline('H2', _T("Beginsaldo"), @d)
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
	    $rep->outline('D', $desc, $bsk_id, $date,
			  $amount >= 0 ? (numfmt($amount), $n0) : ($n0, numfmt(-$amount)),
			  join(":", $dbk_desc, $bsk_nr), $rel||"") if $detail > 1;
	}

	$rep->outline('T2', _T("Totaal mutaties"),
		      $ctot > $dtot ? ("", numfmt($ctot-$dtot)) : (numfmt($dtot-$ctot), ""))
#		      numfmt($dtot), numfmt($ctot))
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
	$did++;
    }

    if ( $did ) {
	$rep->outline('TM', _T("Totaal mutaties"), numfmt($mdgrand), numfmt($mcgrand));
	$rep->outline('TG', _T("Totaal"), numfmt($dgrand), numfmt($cgrand));
    }
    else {
	print("?"._T("Geen informatie gevonden")."\n");
    }

    # Rollback temp table.
    $dbh->rollback;
}

package EB::Report::Grootboek::Text;

use strict;
use EB;
use base qw(EB::Report::GenBase);

my ($title, $per, $adm, $ident, $now);
my ($gbk, $desc, $id, $date, $deb, $crd, $nr, $rel);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

sub start {
    my ($self, $t1, $t2) = @_;
    $title = $t1;
    $per = $t2;
    if ( $self->{boekjaar} ) {
	$adm = $dbh->lookup($self->{boekjaar},
			    qw(Boekjaren bky_code bky_name));
    }
    else {
	$adm = $dbh->adm("name");
    }
    $now = $ENV{EB_SQL_NOW} || iso8601date();
    $ident = $EB::ident;
    $ident = (split(' ', $ident))[0] if $ENV{EB_SQL_NOW};
    $self->{fh}->format_top_name('gbkfmt0');
    $self;
}

sub outline {
    my ($self, $type, @args) = @_;

    ($gbk, $desc, $id, $date, $deb, $crd, $nr, $rel) = ('') x 8;

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
	($desc, $id, $date, $deb, $crd, $nr, $rel) = @args;
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
@||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$per
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $ident . ", " . $now . (" " x (10-length(_T("Relatie"))))

@>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<<<<<  @<<<<<<<<<
_T("GrBk"), _T("Grootboek/Boekstuk"), _T("Datum"), _T("Debet"), _T("Credit"), _T("BoekstukNr"), _T("Relatie")
-----------------------------------------------------------------------------------------@<<<<<<<<<
"-" x length(_T("Relatie"))
.

format gbkfmtl =
-----------------------------------------------------------------------------------------@<<<<<<<<<
"-" x length(_T("Relatie"))
.

format gbkfmt1 =
@>>>>  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<<<<<  @<<<<<<<<<
$gbk, $desc, $date, $deb, $crd, $nr, $rel
.

format gbkfmt2 =
        @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<            @>>>>>>>>> @>>>>>>>>>
$desc, $deb, $crd
.

format gbkfmt3 =
         ^<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>> @>>>>>>>>> @>>>>>>>>>  @<<<<<<<<<<<<<  @<<<<<<<<<
$desc, $date, $deb, $crd, $nr, $rel
~~       ^<<<<<<<<<<<<<<<<<<<<<<<<<<<
$desc
.

1;
