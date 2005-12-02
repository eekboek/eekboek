my $RCS_Id = '$Id: Einde.pm,v 1.4 2005/12/02 15:33:04 jv Exp $ ';

package main;

our $dbh;

package EB::Tools::Einde;

# Einde.pm -- Eindejaarsverwerking
# RCS Info        : $Id: Einde.pm,v 1.4 2005/12/02 15:33:04 jv Exp $
# Author          : Johan Vromans
# Created On      : Sun Oct 16 21:27:40 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Dec  1 19:16:11 2005
# Update Count    : 152
# Status          : Unknown, Use with caution!

use strict;
use warnings;

use EB;
use EB::Finance;
use EB::Report;
use EB::Report::GenBase;
use EB::Report::Journal;

sub new {
    my ($class) = @_;
    $class = ref($class) || $class;
    return bless {} => $class;
}

sub min($$) { $_[0] lt $_[1] ? $_[0] : $_[1] }

sub perform {
    my ($self, $args, $opts) = @_;

    # Akties:
    # Afboeken resultaatrekeningen -> Winstrekening
    # Afboeken BTW I/V H/L -> BTW Betaald

    my $tot = 0;

    my $date = $ENV{EB_SQL_NOW} || iso8601date();
    $date = $dbh->adm("end") unless $date lt $dbh->adm("end");

    my $sth;
    my $rr;
    my $jnl = $opts->{journal};
    my $bky = $opts->{boekjaar};
    my $def = $opts->{definitief};

    my ($acc_id, $acc_desc, $acc_balance);

    warn("?",_T("Geen boekjaar opgegeven")."\n"), return unless $bky;

    $rr = $dbh->do("SELECT bky_begin, bky_end, bky_closed".
		   " FROM Boekjaren".
		   " WHERE bky_code = ?", $bky);
    warn("?",__x("Onbekend boekjaar: {bky}", bky => $bky)."\n"), return unless $rr;

    my ($begin, $end, $closed) = @$rr;
    if ( $closed ) {
	if ( $opts->{verwijder} ) {
	    warn("?",__x("Boekjaar {bky} is definitief afgesloten", bky => $bky)."\n");
	}
	else {
	    warn("?",__x("Boekjaar {bky} is reeds definitief afgesloten", bky => $bky)."\n");
	}
	return;
    }

    $dbh->sql_exec("DELETE FROM Boekjaarbalans where bkb_bky = ?", $bky)->finish;

    $dbh->commit, return if $opts->{verwijder};

    my $rep;
    $rep = EB::Report::GenBase->backend(EB::Report::Journal::, $opts) if $jnl;

    my $tbl = EB::Report::->GetTAccountsBal($end);

    $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balance".
			  " FROM ${tbl}".
			  " WHERE NOT acc_balres".
			  " AND acc_balance <> 0".
			  " ORDER BY acc_id");

    my $edt = parse_date($end, undef, 1);
    my $dtot = 0;
    my $ctot = 0;
    my $did;
    my $desc;
    while ( $rr = $sth->fetchrow_arrayref ) {
	($acc_id, $acc_desc, $acc_balance) = @$rr;
	$tot += $acc_balance;
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $acc_id, $acc_balance, $end);
	$did++, next unless $jnl;

	unless ( $did++ ) {
	    $rep->start(_T("Journaal"),
			__x("Afsluiting boekjaar {bky}", bky => $bky));
	}
	unless ( $desc ) {
	    $rep->outline('H', $end, undef, 1, "<<"._T("Systeemdagboek").">>:$bky", "");
	    $desc = "Afboeken Resultaatrekeningen";
	}
	$acc_balance = -$acc_balance;
	$rep->outline('D', $end, $dbh->lookup($acc_id, qw(Accounts acc_id acc_desc)),
		      $acc_id, numdebcrd($acc_balance), $desc, '');
	$dtot += $acc_balance if $acc_balance > 0;
	$ctot -= $acc_balance if $acc_balance < 0;
    }
    if ( $did ) {
	my $d = '<< ' . ($tot <= 0 ?
			 __x("Winst boekjaar {bky}", bky => $bky) :
			 __x("Verlies boekjaar {bky}", bky => $bky)) . ' >>';

	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $dbh->std_acc("winst"), -$tot, $end);

	if ( $jnl ) {
	    $tot = -$tot;
	    $rep->outline('D', $end, $d, #$dbh->lookup($acc_id, qw(Accounts acc_id acc_desc)),
			  $dbh->std_acc("winst"), numdebcrd(-$tot), $desc, '');
	    $ctot += $tot if $tot > 0;
	    $dtot -= $tot if $tot < 0;
	}
    }

    $tot = 0;
    $desc = "";
    for ( qw(ih il vh vl) ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM ${tbl}".
		     " WHERE acc_id = ?",
		     $dbh->std_acc("btw_$_"))};
	next unless $acc_balance;
	$tot += $acc_balance;
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $acc_id, $acc_balance, $end);
	$did++, next unless $jnl;

	unless ( $did++ ) {
	    $rep->start(_T("Journaal"),
			__x("Afsluiting boekjaar {bky}", bky => $bky));
	}
	elsif ( !$desc ) {
	    $rep->outline(' ');
	}
	unless ( $desc ) {
	    $rep->outline('H', $end, undef, 2, "<<"._T("Systeemdagboek").">>:$bky", "");
	    $desc = "Afboeken BTW rekeningen";
	}

	$acc_balance = -$acc_balance;
	$rep->outline('D', $end, $dbh->lookup($acc_id, qw(Accounts acc_id acc_desc)),
		      $acc_id, numdebcrd($acc_balance), $desc, '');
	$dtot += $acc_balance if $acc_balance > 0;
	$ctot -= $acc_balance if $acc_balance < 0;
    }
    if ( $did ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM ${tbl}".
		     " WHERE acc_id = ?",
		     $dbh->std_acc("btw_ok"))};
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $acc_id, -$tot, $end);

	if ( $jnl ) {
	    $tot = -$tot;
	    $rep->outline('D', $end, $acc_desc, $acc_id, numdebcrd(-$tot), $desc, '');
	    $ctot += $tot if $tot > 0;
	    $dtot -= $tot if $tot < 0;
	}
    }

    if ( $jnl && $did ) {
	$rep->outline('T', __x("Totaal {pfx}",
			      pfx => __x("Afsluiting boekjaar {bky}", bky => $bky)),
		      $dtot, $ctot);

	$rep->finish;
    }

    if ( $def ) {
	$dbh->sql_exec("UPDATE Boekjaren".
		       " SET bky_closed = now()".
		       " WHERE bky_code = ?", $bky)->finish;
    }

    $dbh->commit;
    undef;
}


1;
