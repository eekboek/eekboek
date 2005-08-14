#!/usr/bin/perl -w
my $RCS_Id = '$Id: Schema.pm,v 1.1 2005/08/14 16:11:54 jv Exp $ ';

# Skeleton for Getopt::Long.

# Author          : Johan Vromans
# Created On      : Tue Sep 15 15:59:04 1992
# Last Modified By: Johan Vromans
# Last Modified On: Sun Aug 14 18:10:49 2005
# Update Count    : 57
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

our $dbh;
our $app;
our $config;

# Package name.
my $my_package = 'EekBoek';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $dump = 0;			# dump, what else?
my $verbose = 0;		# verbose processing

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

$dbh = EB::DB->new( trace => $trace,
		  );
$dump ? dump_schema() : load_schema();

exit 0;

################ Subroutines ################

sub dump_schema {
    $dbh->connectdb;		# can't wait...
    print("# $my_package Rekeningschema voor ", $dbh->dbh->{Name}, "\n",
	  "#\n",
	  "# Vlag 1: D = Debet, C = Credit\n",
	  "# Vlag 2: K = Kosten, O = Omzet\n",
	  "# Vlag 3: H = BTW Hoog, L = BTW Laag, G (of leeg) = BTW Geen\n",
	  "\n");

    print("Balansrekeningen\n");
    dump_(1);

    print("\nResultaatrekeningen\n");
    dump_(0);
}

sub dump_ {
    my ($balres) = @_;
    my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
			     " FROM Verdichtingen".
			     " WHERE ".($balres?"":"NOT ")."vdi_balres".
			     " AND vdi_struct IS NULL".
			     " ORDER BY vdi_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc) = @$rr;
	printf("\n  %d  %s\n", $id, $desc);
	print("# HOOFDVERDICHTING MOET TUSSEN 1 EN 9 (INCL.) LIGGEN\n")
	  if $id > 9;
	my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
				 " FROM Verdichtingen".
				 " WHERE vdi_struct = ?".
				 " ORDER BY vdi_id", $id);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($id, $desc) = @$rr;
	    printf("     %-2d  %s\n", $id, $desc);
	    print("# VERDICHTING MOET TUSSEN 10 EN 99 (INCL.) LIGGEN\n")
	      if $id < 10 || $id > 99;
	    my $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balres, acc_debcrd, acc_kstomz, btw_tariefgroep".
				     " FROM Accounts, BTWTabel ".
				     " WHERE acc_struct = ?".
				     " AND btw_id = acc_btw".
				     " ORDER BY acc_id", $id);
	    while ( my $rr = $sth->fetchrow_arrayref ) {
		my ($id, $desc, $acc_balres, $acc_debcrd, $acc_kstomz, $btw) = @$rr;
		my $flags = "";
		$flags .= $acc_debcrd ? "D" : "C";
		$flags .= $acc_kstomz ? "K" : "O";
		$flags .= "H" if $btw == BTWTYPE_HOOG;
		$flags .= "L" if $btw == BTWTYPE_LAAG;
		$flags .= " " if $btw == BTWTYPE_GEEN;
		$desc =~ s/^\s+//;
		$desc =~ s/\s+$//;
		printf("         %-4d  %-3s  %s\n", $id, $flags, $desc);
		print("# $id ZOU EEN BALANSREKENING MOETEN ZIJN\n")
		  if $acc_balres && !$balres;
		print("# $id ZOU EEN RESULTAATREKENING MOETEN ZIJN\n")
		  if !$acc_balres && $balres;
	    }
	}
    }
}

sub load_schema {
    my $balres;
    my @hvdi;
    my @vdi;
    my %acc;
    my $chvdi;
    my $cvdi;
    my $fail = 0;

    while ( <> ) {
	next if /^\#/;
	next unless /\S/;
	if ( /^balans/i ) {
	    $balres = 1;
	    next;
	}
	if ( /^result/i ) {
	    $balres = 0;
	    next;
	}
	chomp;
	if ( /^\s*(\d)\s+(.+)/ ) {
	    $fail++, warn("?Men beginne met \"Balansrekeningen\" of \"Resultaatrekeningen\"\n")
	      unless defined($balres);
	    $fail++, warn("?Dubbel: hoofdverdichting $1\n") if exists($hvdi[$1]);
	    $hvdi[$chvdi = $1] = [ $2, $balres ];
	    next;
	}
	if ( /^\s*(\d\d)\s+(.+)/ ) {
	    $fail++, warn("?Dubbel: verdichting $1\n") if exists($vdi[$1]);
	    $fail++, warn("?Verdichting $1 heeft geen hoofdverdichting\n") unless defined($chvdi);
	    $vdi[$cvdi = $1] = [ $2, $balres, $chvdi ];
	    next;
	}
	if ( /^\s*(\d\d\d+)\s+(\S+)\s+(.+)/ ) {
	    my ($id, $flags, $desc) = ($1, $2, $3);
	    $fail++, warn("?Dubbel: rekening $1\n") if exists($acc{$id});
	    $fail++, warn("?Rekening $id heeft geen verdichting\n") unless defined($cvdi);
	    $fail++, warn("?Rekening $id: onherkenbare vlaggetjes $flags\n")
	      unless $flags =~ /^[dc][ko][hlg]?$/i;
	    my $debcrd = $flags =~ /^d/i;
	    my $kstomz = $flags =~ /^.k/i;
	    my $btw = BTWTYPE_GEEN;
	    $btw = $1 if $flags =~ /^..([hlg])/;
	    $btw = BTWTYPE_HOOG if lc($btw) eq 'h';
	    $btw = BTWTYPE_LAAG if lc($btw) eq 'l';
	    $btw = $dbh->do("SELECT btw_id FROM BTWTabel".
			    " WHERE btw_tariefgroep = ?".
			    " AND btw_incl", $btw)->[0];
	    $acc{$cvdi = $id} = [ $desc, $cvdi, $balres, $debcrd, $kstomz, $btw ];
	    next;
	}
    }
    die("?FOUTEN GEVONDEN, VERWERKING AFGEBROKEN\n") if $fail;

    warn('%'."Aanmaken vrd.sql...\n");
    open(my $f, ">vrd.sql") or die("Cannot create vrd.sql: $!\n");

    print $f ("-- Hoofdverdichtingen\n\n",
	      "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct)".
	      " FROM stdin;\n");
    for ( my $i = 0; $i < @hvdi; $i++ ) {
	next unless exists $hvdi[$i];
	my $v = $hvdi[$i];
	print $f (join("\t", $i, $v->[0], _tf($v->[1]), "\\N", "\\N"), "\n");
    }
    print $f ("\\.\n\n");

    print $f ("-- Verdichtingen\n\n",
	      "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;\n");
    for ( my $i = 0; $i < @vdi; $i++ ) {
	next unless exists $vdi[$i];
	my $v = $vdi[$i];
	print $f (join("\t", $i, $v->[0], _tf($v->[1]), "\\N", $v->[2]), "\n");
    }
    print $f ("\\.\n\n");
    close($f);

    warn('%'."Aanmaken acc.sql...\n");
    open($f, ">acc.sql") or die("Cannot create acc.sql: $!\n");

    print $f ("-- Grootboekrekeningen\n\n",
	      "COPY Accounts (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd,".
	      " acc_kstomz, acc_btw, acc_ibalance, acc_balance) FROM stdin;\n");

    for my $i ( sort { $a <=> $b } keys(%acc) ) {
	my $g = $acc{$i};
	print $f (join("\t", $i, $g->[0], $g->[1],
		       _tf($g->[2]),
		       _tf($g->[3]),
		       _tf($g->[4]),
		       $g->[5], 0, 0), "\n");
    }
    print $f ("\\.\n\n");
    close($f);

    close($f)

}

sub _tf {
    qw(f t)[shift];
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
		     'dump'	=> \$dump,
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
    -dump		dump
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}
