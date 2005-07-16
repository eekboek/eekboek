#!/usr/bin/perl -w
my $RCS_Id = '$Id: Opening.pm,v 1.2 2005/07/16 16:43:51 jv Exp $ ';

# Skeleton for Getopt::Long.

# Author          : Johan Vromans
# Created On      : Sat Jul 16 15:21:55 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jul 16 18:40:34 2005
# Update Count    : 42
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Package or program libraries, if appropriate.
# $LIBDIR = $ENV{'LIBDIR'} || '/usr/local/lib/sample';
# use lib qw($LIBDIR);
# require 'common.pl';

# Package name.
my $my_package = 'Sciurix';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $admin;			# admin name
my $period;			# period
my $check;			# check total
my $btwperiod;			# BTW periode
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = $ENV{EB_SQL_TRACE};
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

################ The Process ################

use EB::Globals;
use EB::DB;
use EB::Finance;
use EB::Report::Text;

use Text::ParseWords;

use locale;

our $dbh = EB::DB->new(trace => $trace);

my $date;
if ( $date = $dbh->get_value("adm_opened", "Metadata") ) {
  die("Openingsbalans is reeds ingevoerd op $date\n");
}
else {
    my @tm = localtime(time);
    $date = sprintf("%04d-%02d-%02d",
		    1900 + $tm[5], 1 + $tm[4], $tm[3]);
    if ( defined($period) ) {
	die("Ongeldige periode: $period\n")
	  unless $period =~ /^\d+$/ && $period > 1990 && $period < 2000 + $tm[5];
	$period = sprintf("%04d-01-01", $period);
    }
}

my $totd = 0;
my $totc = 0;
my $fail;

my $rep = new EB::Report::Text;

my $rr;
my $odate;
if ( defined($period) ) {
    $odate = $period;
    $dbh->sql_exec("UPDATE Metadata SET adm_begin = ?", $odate);
}
else {
    $rr = $dbh->do("SELECT adm_begin FROM Metadata");
    $odate = $rr->[0];
}

$rr = $dbh->do("SELECT now()");
$rep->addline('H', '',
	      "Openingsbalans" .
	      " -- Periode ". substr($odate, 0, 4) . " d.d. " .
		  substr($rr->[0],0,10));

my $crd_open = 0;
my $deb_open = 0;
my $dbk_inkoop;
my $dbk_verkoop;

my ($deb_acct, $crd_acct) = @{$dbh->do("SELECT std_acc_deb, std_acc_crd".
				       " FROM Standaardrekeningen")};

my $action = \&balansregel;

while ( <> ) {
    chomp;
    next if /^\s*#/;
    next unless /\S/;

    my (@args) = shellwords($_);

    if ( @args != 2 && $action == \&balansregel ) {
	balanseinde();
	$action = \&relatieregel;
    }

    $action->(@args);
}

if ( $action == \&balansregel ) {
    balanseinde();
}
else {
    my $highest = $dbh->get_sequence("bsk_nr_0_seq") + 1;
    $dbh->set_sequence("bsk_nr_${dbk_inkoop}_seq", $highest)
      if $dbk_inkoop;
    $dbh->set_sequence("bsk_nr_${dbk_verkoop}_seq", $highest)
      if $dbk_verkoop;
}

if ( $crd_open ) {
    warn("NIET ALLE OPENSTAANDE CREDITEUREN ZIJN INGEVOERD!\n");
    $fail++;
}
if ( $deb_open ) {
    warn("NIET ALLE OPENSTAANDE DEBITEUREN ZIJN INGEVOERD!\n");
    $fail++;
}


$dbh->sql_exec("UPDATE Metadata SET adm_opened = ?", $date);
$dbh->sql_exec("UPDATE Metadata SET adm_name = ?", $admin)
  if defined $admin;
$dbh->sql_exec("UPDATE Metadata SET adm_btwperiod = ?", $btwperiod)
  if defined $admin;

if ( $fail ) {
    $dbh->rollback;
    die("OPENING NIET UITGEVOERD!\n");
}

$dbh->commit;

################ Subroutines ################

sub balansregel {
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

    if ( $acct == $deb_acct ) {
	$deb_open += $amt;
    }
    elsif ( $acct == $crd_acct ) {
	$crd_open -= $amt;
    }

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

sub balanseinde {
    $rep->addline('T', '', "TOTAAL Balans", $totd, $totc);
    unless ( $totd == $totc ) {
	warn("BALANS IS NIET IN EVENWICHT!\n");
	$fail++;
    }
    if ( defined($check) && $check != $totc ) {
	warn("BALANSTOTAAL KLOPT NIET!\n");
	$fail++;
    }
}

sub relatieregel {
    my (@args) = @_;
    my $date;
    if ( $args[0] =~ /^\d+-\d+-\d+$/ ) {
	$date = shift(@args);
    }
    else {
	my @tm = localtime(time);
	$date = sprintf("%04d-%02d-%02d",
			1900 + $tm[5], 1 + $tm[4], $tm[3]);
    }

    my $rr;
    my ($desc, $type, $code, $amt) = @args;
    $amt = amount($amt);
    die("Ongeldige openstaande post: @args\n")
      unless $type =~ /^(deb|crd)$/ && defined($amt);

    my $debcrd = $type eq "deb";

    $rr = $::dbh->do("SELECT rel_acc_id FROM Relaties" .
		     " WHERE rel_code = ?" .
		     "  AND " . ($debcrd ? "" : "NOT ") . "rel_debcrd",
		     $code);
    unless ( defined($rr) ) {
	warn("?Onbekende ".
	     ($debcrd ? "debiteur" : "crediteur").
	     ": $code\n");
	$fail++;
	return;
    }

    my $dagboek;
    if ( $debcrd ) {
	unless ( $dbk_verkoop ) {
	    ($dbk_verkoop) = @{$dbh->do("SELECT dbk_id FROM Dagboeken".
					" WHERE dbk_type = ?",
					DBKTYPE_VERKOOP)};
	}
	$dagboek = $dbk_verkoop;
	$deb_open -= $amt;
    }
    else {
	unless ( $dbk_inkoop ) {
	    ($dbk_inkoop) = @{$dbh->do("SELECT dbk_id FROM Dagboeken".
				       " WHERE dbk_type = ?",
					DBKTYPE_INKOOP)};
	}
	$dagboek = $dbk_inkoop;
	$crd_open -= $amt;
	$amt = -$amt;
    }
    $dbh->sql_insert("Boekstukken",
		     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_paid bsk_amount)],
		     $::dbh->get_sequence("bsk_nr_0_seq"),
		     $desc, $dagboek, $date, undef, $amt);
    $dbh->sql_insert("Boekstukregels",
		     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_rel_code bsr_amount
			 bsr_type)],
		     1, $date,
		     $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr"),
		     $desc, $code, $amt, 9);
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'admin=s'	 => \$admin,
		     'periode=s' => \$period,
		     'check=s'   => sub {
			 $check = amount($_[1]);
			 die("Value \"$_[1]\" invalid for option \"$_[0]\"\n")
			   unless defined $check;
		     },
		     'btw-periode=i' => \$btwperiod,
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace!'	=> \$trace,
		     'help|?'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_ident() if $ident;
}

sub app_ident {
    print STDERR ("This is $my_package [$my_name $my_version]\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    print STDERR <<EndOfUsage;
Usage: $0 [options] [file ...]
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}
