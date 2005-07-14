#!/usr/bin/perl -w

# POC: Openingsbalans

use strict;
use warnings;

use EB::Globals;
use EB::DB;
use EB::Finance;
use EB::Report::Text;

use Text::ParseWords;

use locale;

our $trace = $ENV{EB_SQL_TRACE};

our $dbh = EB::DB->new(trace => $trace);

my $date;
if ( $date = $dbh->get_value("adm_opened", "Metadata") ) {
  die("Openingsbalans is reeds ingevoerd op $date\n");
}
else {
    my @tm = localtime(time);
    $date = sprintf("%04d-%02d-%02d",
		    1900 + $tm[5], 1 + $tm[4], $tm[3]);

}
# grbkrek bedrag [ grbrek bedrag ] ...

my $totd = 0;
my $totc = 0;
my $fail;

unless ( @ARGV ) {
    while ( <STDIN> ) {
	next if /^\s*#/;
	next unless /\S/;
	chomp;
	push(@ARGV, shellwords($_));
    }
}

die("Oneven aantal argumenten\n") if @ARGV % 2;

my $rep = new EB::Report::Text;

my $rr = $dbh->do("SELECT adm_begin FROM Metadata");
my $odate = $rr->[0];
$rr = $dbh->do("SELECT now()");
$rep->addline('H', '',
	      "Openingsbalans" .
	      " -- Periode ". substr($odate, 0, 4) . " d.d. " .
		  substr($rr->[0],0,10));

while ( @ARGV ) {
    my ($acct, $amt) = (shift, shift);
    $amt = amount($amt);
    my $sth = $dbh->sql_exec("SELECT acc_desc, acc_debcrd".
			     " FROM accounts".
			     " WHERE acc_id = ?", $acct);
    my $rr = $sth->fetchrow_arrayref;
    $sth->finish;
    unless ( $rr ) {
	warn("Onbekend grootboekrekeningnummer: $acct\n");
	$fail++;
	next;
    }

    my ($acc_desc, $acc_debcrd) = @$rr;
    unless ( $acc_debcrd ) {
	$amt = -$amt;
	$acc_debcrd = 1 - $acc_debcrd;
    }

    $dbh->sql_exec("UPDATE Accounts".
		   " SET acc_balance = ?,".
		   "     acc_ibalance = ?".
		   " WHERE acc_id = ?",
		   $amt, $amt, $acct);

    if ( $amt < 0 ) {
	$acc_debcrd = 1 - $acc_debcrd;
	$amt = -$amt;
    }

    if ( $acc_debcrd ) {
	$rep->addline('D', $acct, $acc_desc, $amt, '');
	$totd += $amt;
    }
    else {
	$rep->addline('D', $acct, $acc_desc, '', $amt);
	$totc += $amt;
    }
}

$rep->addline('T', '', "TOTAAL Balans", $totd, $totc);
unless ( $totd == $totc ) {
    warn("BALANS IS NIET IN EVENWICHT!\n");
    $fail++;
}

$dbh->sql_exec("UPDATE Metadata SET adm_opened = ?", $date);
if ( $fail ) {
    $dbh->rollback;
    die("OPENINGSBALANS NIET INGEVOERD!\n");
}
$dbh->commit;
