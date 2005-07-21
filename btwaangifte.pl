#!/usr/bin/perl -w
my $RCS_Id = '$Id: btwaangifte.pl,v 1.3 2005/07/21 15:30:32 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Tue Jul 19 19:01:33 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 21 14:23:46 2005
# Update Count    : 113
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

# Package name.
my $my_package = 'EekBoek';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Command line parameters ################

use EB::DB;
my $trace = $ENV{EB_SQL_TRACE};
our $dbh = EB::DB->new(trace=>$trace);

my ($adm_begin, $adm_name, $adm_btw_periode) =
  @{$dbh->do("SELECT adm_begin, adm_name, adm_btwperiod FROM Metadata")};
$adm_btw_periode ||= 4;

unless ( $adm_begin ) {
    die("?Administratie is nog niet geopend\n");
}

use Getopt::Long 2.13;

# Command line options.
my $periode;
my $p_start;
my $p_end;
my $verbose = 0;		# verbose processing

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);
$dbh->trace($trace);

################ Presets ################

################ The Process ################

use EB::Globals;
use EB::Finance;
use POSIX qw(ceil floor);

my $v;
my $tot = 0;

# 1. Door mij verrichte leveringen/diensten
# 1a. Belast met hoog tarief

my $deb_h = 0;
my $deb_btw_h = 0;

# 1b. Belast met laag tarief

my $deb_l = 0;
my $deb_btw_l = 0;

# 1c. Belast met ander, niet-nul tarief

my $deb_x = 0;
my $deb_btw_x = 0;

# 1d. Belast met 0%/verlegd

my $deb_0 = 0;
my $verlegd = 0;

# 3. Door mij verrichte leveringen
# 3a. Buiten de EU

my $extra_deb = 0;

# 3b. Binnen de EU

my $intra_deb = 0;

# 4. Aan mij verrichte leveringen
# 4a. Van buiten de EU

my $extra_crd = 0;

# 4b. Verwervingen van goederen uit de EU.

my $intra_crd = 0;

# Totaaltellingen.

my $crd_btw = 0;		# BTW betaald (voorheffingen)
my $xx = 0;			# ongeclassificeerd (fout, dus)

# Target: alle boekstukken van type 0 (inkoop/verkoop).

unless ( $periode ) {
    my @tm = localtime(time);
    if ( $adm_btw_periode == 1 ) {
	$p_start = sprintf("%04d-01-01", $tm[5] + 1899);
	$p_end   = sprintf("%04d-12-31", $tm[5] + 1899);
	$periode = substr($p_start, 0, 4);
    }
    elsif ( $adm_btw_periode == 4 ) {
	if ( $tm[4] <= 2 ) {
	    use Time::Local;
	    $p_end   = sprintf("%04d-12-31", $tm[5] + 1899);
	    @tm = localtime(timelocal(0,0,0,1,int((1+$tm[4])/3)*3,2004)-24*3600);
	    $p_start = sprintf("%04d-%02d-01", $tm[5] + 1899, 1+$tm[4]);
	    $periode = "3e kwartaal " . substr($p_start, 0, 4);
	}
	else {
	    my $tm4 = $tm[4]+1;
	    @tm = localtime(timelocal(0,0,0,1,int(($tm4)/3)*3,2004)-24*3600);
	    $p_end = sprintf("%04d-%02d-%02d", $tm[5] + 1900, 1+$tm[4], $tm[3]);
	    @tm = localtime(timelocal(0,0,0,1,int(($tm4)/3 - 1)*3,2004));
	    $p_start   = sprintf("%04d-%02d-01", $tm[5] + 1900, 1+$tm[4]);
	    $periode = (int($tm4/3)+1) ."e kwartaal " . substr($p_start, 0, 4);
	}
    }
}

warn("p_start = $p_start, p_end = $p_end\n");

my $sth = $dbh->sql_exec
  ("SELECT bsr_amount,bsr_acc_id,bsr_btw_id,bsr_btw_acc,rel_debcrd,rel_btw_status".
   " FROM Boekstukregels, Relaties".
   " WHERE bsr_rel_code = rel_code".
   ($periode ? " AND bsr_date >= ? AND bsr_date <= ?" : "").
   " AND bsr_type = 0",
   $periode ? ( $p_start, $p_end ) : ());

my $rr;
while ( $rr = $sth->fetchrow_arrayref ) {
    my ($amt, $acc, $btw_id, $btw_acc, $debcrd, $btw_status) = @$rr;
    my $btg_id = 0;
    my $btw = 0;
    $amt = -$amt if $dbh->lookup($acc, qw(Accounts acc_id acc_debcrd));
    if ( $btw_id ) {
	# Bepaal tariefgroep en splits bedrag uit.
	$btg_id = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
	my $a = EB::Finance::norm_btw($amt, $btw_id);
	$amt = $a->[0] - ($btw = $a->[1]); # ex BTW
    }

    if ( $btw_status == BTW_NORMAAL ) {
	if ( $debcrd ) {
	    if ( $btg_id == BTWTYPE_HOOG ) {
		$deb_h += $amt;
		$deb_btw_h += $btw;
	    }
	    elsif ( $btg_id == BTWTYPE_LAAG ) {
		$deb_l += $amt;
		$deb_btw_l += $btw;
	    }
	    elsif ( $btg_id == BTWTYPE_GEEN ) {
		$deb_0 += $amt
		  if $btw_acc;	# ???
	    }
	    else {
		$deb_x += $amt;
		$deb_btw_x += $btw;
	    }
	}
	else {
	    $crd_btw -= $btw;
	}
    }
    elsif ( $btw_status == BTW_VERLEGD ) {
	if ( $debcrd ) {
	    $verlegd += $amt;
	}
    }
    elsif ( $btw_status == BTW_INTRA ) {
	if ( $debcrd ) {
	    $intra_deb += $amt;
	}
	else {
	    $intra_crd -= $amt;
	}
    }
    elsif ( $btw_status == BTW_EXTRA ) {
	if ( $debcrd ) {
	    $extra_deb += $amt;
	}
	else {
	    $extra_crd -= $amt;
	}
    }
    else {
	# Foutvanger.
	$xx += $amt;
    }
}

print("BTW Aangifte $periode",
      " -- $adm_name\n\n");


# Binnenland
print("Binnenland\n");

# 1. Door mij verrichte leveringen/diensten
print("\n1. Door mij verrichte leveringen/diensten\n\n");

# 1a. Belast met hoog tarief
$v = rounddown($deb_btw_h);
outline("1a", "Belast met hoog tarief", rounddown($deb_h), $v);
$tot += $v;

# 1b. Belast met laag tarief
$v = rounddown($deb_btw_l);
outline("1b", "Belast met laag tarief", rounddown($deb_l), $v);
$tot += $v;

# 1c. Belast met ander, niet-nul tarief
$v = rounddown($deb_btw_x);
outline("1c", "Belast met ander tarief", rounddown($deb_x), $v);
$tot += $v;

# 1d. Belast met 0%/verlegd
$v = rounddown($deb_0 + $verlegd);
outline("1c", "Belast met 0% / verlegd", $v, undef);

# Buitenland
print("\nBuitenland\n");

# 3. Door mij verrichte leveringen
print("\n3. Door mij verrichte leveringen\n\n");

# 3a. Buiten de EU

$v = rounddown($extra_deb);
outline("3a", "Buiten de EU", $v, undef);

# 3b. Binnen de EU

$v = rounddown($intra_deb);
outline("3a", "Binnen de EU", $v, undef);

# 4. Aan mij verrichte leveringen

print("\n4. Aan mij verrichte leveringen\n\n");

# 4a. Van buiten de EU

$v = rounddown($extra_crd);
outline("4a", "Van buiten de EU", $v, 0);

# 4b. Verwervingen van goederen uit de EU.
$v = rounddown($intra_crd);
outline("4b", "Verwervingen van goederen uit de EU", $v, 0);

# 5 Berekening totaal

print("\n5 Berekening totaal\n\n");

# 5a. Subtotaal

outline("5a", "Subtotaal", undef, $tot);

# 5b. Voorbelasting

my ($vb) = @{$dbh->do("SELECT SUM(jnl_amount)".
		      " FROM Journal".
		      " WHERE ( jnl_acc_id = 1530 OR jnl_acc_id = 1520 )".
		      ($periode ? " AND jnl_date >= ? AND jnl_date <= ?" : ""),
		      $periode ? ( $p_start, $p_end ) : ())};
my $btw_delta = $vb - $crd_btw;


$vb = roundup($vb);
outline("5b", "Voorbelasting", undef, $vb);
$tot -= $vb;

# 5c Subtotaal

outline("5c", "Subtotaal", undef, $tot);

outline("xx", "Onbekend", undef, numfmt($xx)) if $xx;

if ( $btw_delta ) {
    warn("!Er is een verschil van ".numfmt($btw_delta).
	 " tussen de berekende en werkelijk ingehouden BTW.".
	 " Voor de aangifte is de werkelijk ingehouden BTW gebruikt.\n");
}
exit 0;

################ Subroutines ################

sub rounddown {
    my ($vb) = @_;
    return 0 unless $vb;
    $vb /= AMTSCALE;
    if ( $vb >= 0 ) {
	$vb = floor($vb);
    }
    else {
	$vb = -ceil(abs($vb));
    }
    $vb;
}

sub roundup {
    my ($vb) = @_;
    return 0 unless $vb;
    $vb /= AMTSCALE;
    if ( $vb >= 0 ) {
	$vb = ceil($vb);
    }
    else {
	$vb = -floor(abs($vb));
    }
    $vb;
}

sub outline {
    my ($tag0, $tag1, $sub, $amt) = @_;
    printf("%-5s%-40s%10s%10s\n",
	   $tag0, $tag1,
	   defined($sub) ? $sub : "",
	   defined($amt) ? $amt : "");
}

################ Subroutines ################

sub parse_periode {
    my ($o, $v) = @_;
    die("Waarde \"$v\" is niet geldig voor optie \"$o\"\n");
}

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'periode=s' => \&parse_periode,
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
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}
