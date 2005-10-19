my $RCS_Id = '$Id: Einde.pm,v 1.2 2005/10/19 16:34:09 jv Exp $ ';

package main;

our $dbh;

package EB::Tools::Einde;

# Einde.pm -- Eindejaarsverwerking
# RCS Info        : $Id: Einde.pm,v 1.2 2005/10/19 16:34:09 jv Exp $
# Author          : Johan Vromans
# Created On      : Sun Oct 16 21:27:40 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Oct 19 14:16:09 2005
# Update Count    : 58
# Status          : Unknown, Use with caution!

use strict;
use warnings;

use EB;
use EB::Finance;

sub new {
    my ($class) = @_;
    $class = ref($class) || $class;
    return bless {} => $class;
}

sub min($$) { $_[0] lt $_[1] ? $_[0] : $_[1] }

my $trace = 0;

sub perform {
    my ($self, $opts) = @_;

    # Akties:
    # Afboeken resultaatrekeningen -> Winstrekening
    # Afboeken BTW I/V H/L -> BTW Betaald

    my $tot = 0;

    my $date = $ENV{EB_SQL_NOW} || iso8601date();
    $date = $dbh->adm("end") unless $date lt $dbh->adm("end");

    my $sth;
    my $rr;
    my $mem;
    my ($acc_id, $acc_desc, $acc_balance);

    my $bky = $opts->{boekjaar};
    warn("?",_T("Geen boekjaar opgegeven")."\n"), return unless $bky;

    $rr = $dbh->do("SELECT bky_name, bky_begin, bky_end, bky_closed".
		   " FROM Boekjaren".
		   " WHERE bky_code = ?", $bky);
    warn("?",__x("Onbekend boekjaar: {bky}", bky => $bky)."\n"), return unless $rr;

    my ($desc, $begin, $end, $closed) = @$rr;
    warn("?",__x("Boekjaar {bky} is reeds afgesloten", bky => $bky)."\n"), return if $closed;

    my $def = $opts->{definitief};

    print("# ", __x("Afsluiting boekjaar {bky} ({desc})",
		    bky => $bky, desc => $desc), "\n\n");

    $dbh->sql_exec("DELETE FROM Boekjaarbalans where bkb_bky = ?", $bky)->finish;

    $self->GetTAccountsBal($date, $end);

    $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balance".
			  " FROM TAccounts".
			  " WHERE NOT acc_balres".
			  " AND acc_balance <> 0".
			  " ORDER BY acc_id");

    while ( $rr = $sth->fetchrow_arrayref ) {
	($acc_id, $acc_desc, $acc_balance) = @$rr;
	$tot += $acc_balance;
	unless ( $mem ) {
	    $mem = "memoriaal $date \"Afboeken resultaatrekeningen\" \\\n";
	}
	$acc_desc =~ s/(["\\])/\\$1/g;
	$mem .= sprintf("\tstd %-30s %9s\@0 %5d \\\n",
			"\"$acc_desc\"",
			numfmt($acc_balance), $acc_id);
    }
    if ( $mem ) {
	$mem .= sprintf("\tstd %-30s %9s   %5d\n",
			'"<< ' . ($tot <= 0 ? _T("Winst") : _T("Verlies")) . ' >>"',
			numfmt(-$tot), $dbh->std_acc("winst"));
	print $mem, "\n";
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $dbh->std_acc("winst"), -$tot, $end);
    }

    $tot = 0;
    $mem = "";
    for ( qw(ih il vh vl) ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM TAccounts".
		     " WHERE acc_id = ?",
		     $dbh->std_acc("btw_$_"))};
	next unless $acc_balance;
	$tot += $acc_balance;
	unless ( $mem ) {
	    $mem = "memoriaal $date \"Afboeken BTW rekeningen\" \\\n";
	}
	$acc_desc =~ s/(["\\])/\\$1/g;
	$mem .= sprintf("\tstd %-30s %9s   %5d \\\n",
			"\"$acc_desc\"",
			numfmt($acc_balance), $acc_id);
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $acc_id, $acc_balance, $end);
    }
    if ( $mem ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM TAccounts".
		     " WHERE acc_id = ?",
		     $dbh->std_acc("btw_ok"))};
	$acc_desc =~ s/(["\\])/\\$1/g;
	$mem .= sprintf("\tstd %-30s %9s   %5d\n",
			'"'.$acc_desc.'"',
			numfmt(-$tot), $acc_id);
	print $mem, "\n";
	$dbh->sql_insert("Boekjaarbalans",
			 [qw(bkb_bky bkb_acc_id bkb_balance bkb_end)],
			 $bky, $acc_id, -$tot, $end);
    }

    $dbh->sql_exec("DROP TABLE TAccounts")->finish;

    if ( $def ) {
	$dbh->sql_exec("UPDATE Boekjaren".
		       " SET bky_closed = now()".
		       " WHERE bky_code = ?", $bky)->finish;
    }

    $dbh->commit;
    undef;
}

sub GetTAccountsBal {
    shift;
    my ($begin, $end) = @_;
    $dbh->sql_exec("SELECT acc_id,acc_desc,acc_balres,acc_debcrd,".
		   "acc_ibalance,acc_ibalance AS acc_balance,acc_struct".
		   " INTO TEMP TAccounts".
		   " FROM Accounts")->finish;
    my $sth = $dbh->sql_exec("SELECT jnl_acc_id,acc_balance,SUM(jnl_amount)".
			     " FROM Journal,TAccounts".
			     " WHERE acc_id = jnl_acc_id".
			     " AND jnl_date <= ?".
			     " GROUP BY jnl_acc_id,acc_balance,acc_ibalance",
			     $end);

    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($acc_id, $acc_balance, $sum) = @$rr;
	my $corr = $dbh->do("SELECT bkb_balance".
			    " FROM Boekjaarbalans".
			    " WHERE bkb_acc_id = ?".
			    " AND bkb_end < ?", $acc_id, $begin);
	$sum -= $corr->[0] if $corr;
	next unless $sum;
	$sum += $acc_balance;
	warn("!".__x("Grootboekrekening {acct}, saldo aangepast naar {exp}",
		     acct => $acc_id, exp => numfmt($sum)) . "\n") if $trace;
	$dbh->sql_exec("UPDATE TAccounts".
		       " SET acc_balance = ?".
		       " WHERE acc_id = ?",
		       $sum, $acc_id)->finish;
    }
    "TAccounts";
}

sub GetTAccountsRes {
    shift;
    my ($begin, $end) = @_;

    $dbh->sql_exec("SELECT acc_id,acc_desc,acc_balres,acc_debcrd,".
		   "0 AS acc_ibalance,0 AS acc_balance,acc_struct".
		   " INTO TEMP TAccounts".
		   " FROM Accounts".
		   " WHERE NOT acc_balres")->finish;
    my $sth = $dbh->sql_exec("SELECT jnl_acc_id,SUM(jnl_amount)".
			     " FROM Journal,TAccounts".
			     " WHERE acc_id = jnl_acc_id".
			     " AND jnl_date >= ?".
			     " AND jnl_date <= ?".
			     " GROUP BY jnl_acc_id",
			     $begin, $end);

    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($acc_id, $sum) = @$rr;
	next unless $sum;
	warn("!".__x("Grootboekrekening {acct}, saldo aangepast naar {exp}",
		     acct => $acc_id, exp => numfmt($sum)) . "\n") if $trace;
	$dbh->sql_exec("UPDATE TAccounts".
		       " SET acc_balance = ?".
		       " WHERE acc_id = ?",
		       $sum, $acc_id)->finish;
    }
    "TAccounts";
}

sub GetTAccountsCopy {
    shift;
    $dbh->sql_exec("SELECT acc_id,acc_desc,acc_balres,acc_debcrd,acc_ibalance,acc_balance,acc_struct".
		   " INTO TEMP TAccounts".
		   " FROM Accounts")->finish;
    "TAccounts";
}

1;
