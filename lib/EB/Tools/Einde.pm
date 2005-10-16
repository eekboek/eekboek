my $RCS_Id = '$Id: Einde.pm,v 1.1 2005/10/16 21:19:23 jv Exp $ ';

package main;

our $dbh;

package EB::Tools::Einde;

# Einde.pm -- Eindejaarsverwerking
# RCS Info        : $Id: Einde.pm,v 1.1 2005/10/16 21:19:23 jv Exp $
# Author          : Johan Vromans
# Created On      : Sun Oct 16 21:27:40 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Oct 16 23:04:25 2005
# Update Count    : 29
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

sub perform {
    my ($self, $opts) = @_;

    # Akties:
    # Afboeken resultaatrekeningen -> Winstrekening
    # Afboeken BTW I/V H/L -> BTW Betaald

    my $tot = 0;

    my $date = iso8601date();
    $date = $dbh->adm("end") unless $date lt $dbh->adm("end");

    my $sth;
    my $rr;
    my $mem;
    my ($acc_id, $acc_desc, $acc_balance);

    $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balance".
			  " FROM Accounts".
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
			'"<< ' . ($tot > 0 ? _T("Winst") : _T("Verlies")) . ' >>"',
			numfmt(-$tot), $dbh->std_acc("winst"));
	print $mem, "\n";
    }

    $tot = 0;
    $mem = "";
    for ( qw(ih il vh vl) ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM Accounts".
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
    }
    if ( $mem ) {
	($acc_id, $acc_desc, $acc_balance) =
	  @{$dbh->do("SELECT acc_id,acc_desc,acc_balance".
		     " FROM Accounts".
		     " WHERE acc_id = ?",
		     $dbh->std_acc("btw_ok"))};
	$acc_desc =~ s/(["\\])/\\$1/g;
	$mem .= sprintf("\tstd %-30s %9s   %5d\n",
			'"'.$acc_desc.'"',
			numfmt(-$tot), $acc_id);
	print $mem, "\n";
    }

    undef;
}

1;
