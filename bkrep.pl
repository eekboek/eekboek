#!/usr/bin/perl -w
my $RCS_Id = '$Id: bkrep.pl,v 1.9 2005/07/30 18:24:24 jv Exp $ ';

# Skeleton for Getopt::Long.

# Author          : Johan Vromans
# Created On      : 2005.07.14.12.54.08
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jul 30 18:45:37 2005
# Update Count    : 47
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
my $trail = 0;

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

use EB::Globals;
use EB::DB;
use EB::Finance;

use locale;

our $dbh = EB::DB->new(trace => $trace);

my $sth;

my $ob = $trail ? "bsk_date," : "";

if ( @ARGV ) {
    my $nr = shift;
    if ( $nr =~ /^([[:alpha:]].+):(\d+)$/ ) {
	my $dbk = $::dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE bsk_nr = ?".
			      " AND dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $2, $dbk);
    }
    elsif ( $nr =~ /^([[:alpha:]].+)$/ ) {
	my $dbk = $::dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $dbk);
    }
    else {
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken".
			      " WHERE bsk_id = ?".
			      " ORDER BY ${ob}bsk_dbk_id,bsk_nr", $nr);
    }
}
else {
    $sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			  "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			  " FROM Boekstukken".
			  " ORDER BY ${ob}bsk_dbk_id,bsk_nr");
}

my $rr;

my $ret = [];
my $did = 0;

my @bsr_types =
  ([],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [],
  );

while ( $rr = $sth->fetchrow_arrayref ) {
    my ($bsk_id, $bsk_nr, $bsk_desc, $bsk_dbk_id,
	$bsk_date, $bsk_amount, $bsk_paid) = @$rr;
    $bsk_nr =~ s/\s+$//;
    my $sth = $dbh->sql_exec("SELECT bsr_id, bsr_nr, bsr_date, ".
			     "bsr_desc, bsr_amount, bsr_btw_id, ".
			     "bsr_type, bsr_acc_id, bsr_rel_code ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?".
			     " ORDER BY bsr_nr", $bsk_id);
    my $tot = 0;
    my $rr;
    my ($dbktype, $acct, $dbk_desc) = @{$dbh->do("SELECT dbk_type, dbk_acc_id, dbk_desc".
						 " FROM Dagboeken".
						 " WHERE dbk_id = ?", $bsk_dbk_id)};
    my $cmd = lc($dbk_desc);
    $cmd =~ s/[^[:alnum:]]/_/g;

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount,
	    $bsr_btw_id, $bsr_type, $bsr_acc_id, $bsr_rel_code) = @$rr;
	$bsr_rel_code =~ s/\s+$// if $bsr_rel_code;

	if ( $bsr_nr == 1) {
	    if ( $trail ) {
		$cmd .= ":$bsk_nr $bsk_date ";
		$cmd .= "\"$bsr_rel_code\""
		  if $dbktype == DBKTYPE_VERKOOP || $dbktype == DBKTYPE_INKOOP;
		$cmd .= "\"$bsk_desc\""
		  if $dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS || $dbktype == DBKTYPE_MEMORIAAL;
	    }
	    else {
		print("\n") if $did++;
		print("Boekstuk $bsk_id, nr $bsk_nr, dagboek ",
		      $dbh->lookup($bsk_dbk_id, qw(Dagboeken dbk_id dbk_desc =)),
		      "($bsk_dbk_id)",
		      ", datum $bsk_date",
		      ", ");
		if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
		    my ($rd, $rt) = @{$::dbh->do("SELECT rel_desc,rel_debcrd".
						 " FROM Relaties".
						 " WHERE rel_code = ?",
						 $bsr_rel_code)};
		    print($rt ? "deb " : "crd ", "$bsr_rel_code ($rd), ");
		}
		print("\"$bsk_desc\"", $bsk_paid ? ", *$bsk_paid" : ", open", "\n");
	    }
	}

	my ($rd, $rt) = $bsr_acc_id ?
	  @{$::dbh->do("SELECT acc_desc,acc_debcrd".
		       " FROM Accounts".
		       " WHERE acc_id = ?",
		       $bsr_acc_id)}
	    : ("[Open posten vorige periode]", 1);

	my $dc = $bsr_amount >= 0 ? "debet" : "credit";
	$dc = uc($dc) unless ($bsr_amount < 0) ^ $rt;
	print(" Boekstukregel $bsr_id, nr $bsr_nr, datum $bsr_date, ",
	      "\"$bsr_desc\"",
	      ", type $bsr_type (", $bsr_types[$dbktype][$bsr_type], ")\n",
	      "  ",
	      "bedrag ", numfmt(abs($bsr_amount)), " ", $dc,
	      defined($bsr_btw_id) ?
	      (", BTW code $bsr_btw_id (",
	      $dbh->lookup($bsr_btw_id, qw(BTWTabel btw_id btw_desc)),
	      ")") : (),
	      defined($bsr_acc_id) ? (", rek $bsr_acc_id (", $rt ? "D/" : "C/", $rd, ")",) : (),
	      "\n") unless $trail;

	#$bsr_amount = -$bsr_amount unless $rt;
	my $a = EB::Finance::norm_btw($bsr_amount, $bsr_btw_id);
	$tot += $a->[0];

	next unless $trail;

	if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
	    $cmd .= " \"$bsr_desc\" " .
	      numfmt(abs($bsr_amount)) . "@" . $bsr_btw_id . " " .
		$bsr_acc_id . uc(substr($dc,0,1));
	}
	elsif ( $dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS
		|| $dbktype == DBKTYPE_MEMORIAAL ) {
	    if ( $bsr_type == 0 ) {
		$cmd .= " std \"$bsr_desc\" " .
		  numfmt(abs($bsr_amount)) . "@" . $bsr_btw_id . " " .
		    $bsr_acc_id . uc(substr($dc,0,1));
	    }
	    elsif ( $bsr_type == 1 ) {
		$cmd .= " deb \"$bsr_rel_code\" " .
		  numfmt($bsr_amount);
	    }
	    elsif ( $bsr_type == 2 ) {
		$cmd .= " crd \"$bsr_rel_code\" " .
		  numfmt($bsr_amount);
	    }
	}

    }

    print($cmd, "\n"), next if $trail;

    unless ( $acct ) {
	print("BOEKSTUK IS NIET IN BALANS -- VERSCHIL IS ", numfmt($tot), "\n")
	  if $tot;
	next;
    }
    my ($rd, $rt) = @{$::dbh->do("SELECT acc_desc,acc_debcrd".
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

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'trail'    => \$trail,
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
    -trail		produce trail
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}
