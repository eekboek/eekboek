#!/usr/bin/perl -w
my $RCS_Id = '$Id: trail.pl,v 1.1 2005/09/20 16:13:36 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sun Aug 21 10:31:25 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 20 18:09:09 2005
# Update Count    : 138
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

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
my $verbose = 0;		# verbose processing
my $ex_bsknr = 1;		# explicit boekstuknummers
my $ex_btw = 0;			# explicit btw code
my $ex_debcrd = 0;		# explicit D/C
my $single = 0;			# one line
my $trail = 1;

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

our $dbh;

use EB;
use EB::Finance;
use EB::DB;
use EB::Booking::Decode;

use locale;

$dbh = EB::DB->new(trace => $trace);

my $sth;

my $ob = $trail ? "bsk_date," : "";

if ( @ARGV ) {
    my $nr = shift;
    if ( $nr =~ /^([[:alpha:]].+):(\d+)$/ ) {
	my $dbk = $dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE bsk_nr = ?".
			      " AND dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $2, $dbk);
    }
    elsif ( $nr =~ /^([[:alpha:]].+)$/ ) {
	my $dbk = $dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $dbk);
    }
    else {
	$sth = $dbh->sql_exec("SELECT bsk_id".
			      " FROM Boekstukken".
			      " WHERE bsk_id = ?".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $nr);
    }
}
else {
    $sth = $dbh->sql_exec("SELECT bsk_id".
			  " FROM Boekstukken".
			  " ORDER BY ${ob}bsk_dbk_id,bsk_nr");
}

my $rr;
my $did = 0;

while ( $rr = $sth->fetchrow_arrayref ) {
    my ($bsk_id) = @$rr;

    if ( $trail && !$verbose ) {
	print(scalar(EB::Booking::Decode->decode($bsk_id,
						 { trail  => 1,
						   single => $single,
						   btw    => $ex_btw,
						   bsknr  => $ex_bsknr,
						   debcrd => $ex_debcrd})), "\n");
	next;
    }

    my ($cmd, $tot, $bsk_amount, $acct) = EB::Booking::Decode->decode($bsk_id,
								      { trail => 0 });
    print("\n") if $did++;
    print($cmd);
    unless ( $acct ) {
	print("BOEKSTUK IS NIET IN BALANS -- VERSCHIL IS ", numfmt($tot), "\n")
	  if $tot;
	next;
    }
    my ($rd, $rt) = @{$dbh->do("SELECT acc_desc,acc_debcrd".
			       " FROM Accounts".
			       " WHERE acc_id = ?",
			       $acct)};

    $tot = -$tot if $rt;
    #$bsk_amount = -$bsk_amount if $rt;
    my $dc = $tot >= 0 ? "debet" : "credit";
    $dc = uc($dc) unless ($tot < 0) ^ $rt;
    print("TOTAAL Bedrag ", numfmt(abs($tot)), " ", $dc,
	  ", rek $acct (", $rt ? "D/" : "C/", $rd, ")\n");
    print("TOTAAL BEDRAG ", numfmt($tot), " KLOPT NIET MET BOEKSTUK $bsk_id TOTAAL ", numfmt($bsk_amount), "\n")
#      unless $bsk_amount == $tot;
      # This silences a lot of warnings, have to find out why.
      unless abs($bsk_amount) == abs($tot);
}

################ Subroutines ################

my %btw_code;
sub btw_code {
    my($acct) = @_;
    return $btw_code{$acct} if defined $btw_code{$acct};
    _lku($acct);
    $btw_code{$acct};
}

sub _lku {
    my ($acct) = @_;
    my $rr = $dbh->do("SELECT acc_btw".
		      " FROM Accounts".
		      " WHERE acc_id = ?", $acct);
    die("?".__x("Onbekend rekeningnummer: acct}", acct => $acct)."\n")
      unless $rr;
    $btw_code{$acct} = $rr->[0];
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'btw!'     => \$ex_btw,
		     'bsknr!'   => \$ex_bsknr,
		     'debcrd!'  => \$ex_debcrd,
		     'all'      => sub { $ex_debcrd = $ex_btw = $ex_bsknr = 1 },
		     'single'	=> \$single,
		     'ident'	=> \$ident,
		     'verbose'	=> \$verbose,
		     'trace'	=> \$trace,
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
    -btw		expliciete aanduiding voor BTW
    -bsknr		expliciete aanduiding voor boekstuknummers
    -debcrd		expliciete aanduiding voor debet/credit
    -all		alles expliciet
    -single		elk boekstuk geheel op een regel
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}
