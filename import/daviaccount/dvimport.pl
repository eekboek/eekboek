#!/usr/bin/perl -w
my $RCS_Id = '$Id: dvimport.pl,v 1.2 2005/07/17 19:40:22 jv Exp $ ';

# Skeleton for Getopt::Long with Pod::Parser.

# Author          : Johan Vromans
# Created On      : Sun Sep 15 18:39:01 1996
# Last Modified By: Johan Vromans
# Last Modified On: Sun Jul 17 21:33:39 2005
# Update Count    : 193
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

use POSIX qw(tzset strftime);
tzset();
my @tm = localtime(time);
my $tsdate = strftime("%Y-%m-%d %k:%M:%S +0100", @tm[0..5], -1, -1, -1);

################ The Process ################

use Digest::MD5 qw(md5_hex);
use EB::Globals;
use EB::Finance;

read_exact_data();

#read_dagboeken();
#read_hoofdverdichtingen();
#read_verdichtingen();
#read_grootboek();
#read_btw();

write_rekeningschema();

exit 0;

################ Subroutines ################

use Data::Dumper;

my $db;

sub read_exact_data {

    open ($db, "<EXACT61.TXT") || die("Missing: EXACT61.TXT\n");
    my $next;
    while ( <$db> ) {
	if ( /^HOOFDVERDICHTINGEN/ ) {
	    $next = \&read_hoofdverdichtingen;
	}
	elsif ( /^VERDICHTINGEN/ ) {
	    $next = \&read_verdichtingen;
	}
	elsif ( /^BTW-TARIEVEN/ ) {
	    $next = \&read_btw;
	}
	elsif ( /^DAGBOEKEN/ ) {
	    $next = \&read_dagboeken;
	}
	elsif ( /^-{40}/ ) {
	    $next->();
	}
    }
    close($db);
    read_grootboek();
}


my @dagboeken;

sub read_dagboeken {
    while ( <$db> ) {
	last unless $_ =~ /\S/;
	# 1     Kas                                      Kas                 1000
	my @a = unpack("a6a41a20a6", $_);
	for ( @a[1,2] ) {
	    s/\s+$//;
	}
	$dagboeken[0+$a[0]] = [ @a[1,2], $a[3] eq "N.v.t." ? "\\N" : 0+$a[3] ];
    }
    # print Dumper(\@dagboeken);
}

my @hoofdverdichtingen;

sub read_hoofdverdichtingen {
    while ( <$db> ) {
	last unless $_ =~ /\S/;
	# 2        Vlottende activa
	my @a = unpack("a9a*", $_);
	for ( $a[1] ) {
	    s/\s+$//;
	}
	$hoofdverdichtingen[$a[0]] = [ $a[1], undef ]; # desc balres
    }
}

my @verdichtingen;

sub read_verdichtingen {
    while ( <$db> ) {
	last unless $_ =~ /\S/;
	# 21       Handelsvoorraden                             2
	my @a = unpack("a9a45a*", $_);
	for ( $a[1] ) {
	    s/\s+$//;
	}
	$verdichtingen[$a[0]] = [ $a[1], undef, undef, 0+$a[2] ]; # desc balres kstomz hoofdverdichting
    }
}

my %grootboek;
my @transactions;

sub read_grootboek {
    use Text::CSV_XS;
    my $csv = new Text::CSV_XS ({binary => 1});
    open (my $db, "<GRTBK.CSV")
      || die("Missing: GRTBK.CSV\n");
    while ( <$db> ) {
	if ( $csv->parse($_) ) {
	    my @a = $csv->fields();
	    $grootboek{0+$a[0]} =
	      [ @a[1,3,4,5,6,7,12] ]; # desc B/W D/C N/.. struct btw N/J(omzet)?
	    my $balance = $a[17] - $a[16];
	    if ( $balance ) {
		push(@transactions,
		     [0+$a[0],
		      $a[4] eq 'C' ? $balance : -$balance]);
	    }
	    $balance = $a[19] - $a[18];
	    if ( $balance ) {
		warn(sprintf("GrbRk $a[0]: saldo = %.2f\n", $balance));
	    }
	    $verdichtingen[$a[6]][1] = $a[3];  # balres
	    $verdichtingen[$a[6]][2] = $a[12]; # kstomz
	}
	else {
	    warn("Parse error at line $.\n");
	}
    }
    # print Dumper(\%grootboek);
    foreach ( @verdichtingen ) {
	next unless $_;
	$hoofdverdichtingen[$_->[3]][1] = $_->[1];
	$hoofdverdichtingen[$_->[3]][2] = $_->[2];
    }
}

my @btwtable;

sub read_btw {
    my $hi;
    my $lo;
    while ( <$db> ) {
	last unless $_ =~ /\S/;
	# Nr.   Omschrijving                             Perc.  Type  Ink.reknr. Verk.reknr.
	# ----------------------------------------------------------------------------------
	# 1     BTW 17,5% incl.                          17,50  Incl. 1520       1500       
	# 123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890
	#          1         2         3         4         5         6         7         8         9
	my @a = unpack("a6a41a7a6a11a*", $_);
	for ( @a[1,2,3] ) {
	    s/\s+$//;
	}

	my $btw = amount($a[2]);
	if ( AMTPRECISION > BTWPRECISION-2 ) {
	    $btw = substr($btw, 0, length($btw) - (AMTPRECISION - BTWPRECISION-2))
	}
	elsif ( AMTPRECISION < BTWPRECISION-2 ) {
	    $btw .= "0" x (BTWPRECISION-2 - AMTPRECISION);
	}
	$btwtable[$a[0]] = [ $a[1], $btw,
			     $a[3] eq "Incl." ? 't' : 'f' ];
	if ( $btw ) {
	    if ( !$lo || $btw < $lo ) {
		$lo = $btw;
	    }
	    if ( !$hi || $btw > $hi ) {
		$hi = $btw;
	    }
	}
    }
    foreach ( @btwtable ) {
	push(@$_, $_->[1] == 0 ? 3 :
	     $_->[1] == $hi ? 1 :
	     $_->[1] == $lo ? 2 : warn("Onbekende BTW group: $_->[1]\n"));
    }

    open(OUT, ">btw.sql");

    print OUT ("-- BTW Tariefgroepen\n\n",
	       "COPY BTWTariefgroepen (btg_id, btg_desc, btg_perc) FROM stdin;\n",
	       "1\tBTW Hoog ".btwfmt($hi)."%\t$hi\n",
	       "2\tBTW Laag ".btwfmt($lo)."%\t$lo\n",
	       "1\tBTW Geen\t0\n",
	       "\\.\n\n");

    print OUT ("-- BTW Tabel\n\n",
	       "COPY BTWTabel (btw_id, btw_desc, btw_perc, btw_incl, btw_tariefgroep) FROM stdin;\n");

    for ( my $i = 0; $i < @btwtable; $i++ ) {
	next unless exists $btwtable[$i];
	my $b = $btwtable[$i];
	print OUT (join("\t", $i, @$b), "\n");
    }

    print OUT ("\\.\n\n");
    close(OUT);

}

sub write_rekeningschema {

    open(OUT, ">vrd.sql");
    select(OUT);

    print("-- Hoofdverdichtingen\n\n",
	  "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;\n");
    for ( my $i = 0; $i < @hoofdverdichtingen; $i++ ) {
	next unless exists $hoofdverdichtingen[$i];
	my $v = $hoofdverdichtingen[$i];
	# Skip unused verdichtingen.
	next unless defined($v->[1]) && defined($v->[2]);
	print(join("\t", $i,
		   $v->[0],
		   $v->[1] eq 'B' ? 't' : 'f',
		   $v->[2] eq 'N' ? 't' : 'f',
		   "\\N"), "\n");
    }
    print("\\.\n\n");

    print("-- Verdichtingen\n\n",
	  "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;\n");
    for ( my $i = 0; $i < @verdichtingen; $i++ ) {
	next unless exists $verdichtingen[$i];
	my $v = $verdichtingen[$i];
	# Skip unused verdichtingen.
	next unless defined($v->[1]) && defined($v->[2]);
	print(join("\t", $i,
		   $v->[0],
		   $v->[1] eq 'B' ? 't' : $v->[1] eq 'W' ? 'f' : '?',
		   $v->[2] eq 'N' ? 't' : $v->[2] eq 'J' ? 'f' : '?',
		   $v->[3]), "\n");
    }
    print("\\.\n\n");

    open(OUT, ">acc.sql");
    select(OUT);

    print("-- Grootboekrekeningen\n\n",
	  "COPY Accounts (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd,".
	  " acc_kstomz, acc_btw, acc_ibalance, acc_balance) FROM stdin;\n");

    for my $i ( sort { $a <=> $b } keys(%grootboek) ) {
	my $g = $grootboek{$i};
	# desc B/W D/C N/.. struct btw N/J(omzet)?
	print(join("\t", $i,
		   $g->[0],
		   $g->[4],
		   $g->[1] eq 'B' ? 't' : 'f',
		   $g->[2] eq 'D' ? 't' : 'f',
		   $g->[6] eq 'N' ? 't' : 'f',
		   $g->[5],
		   0,
		   0), "\n");
    }
    print("\\.\n\n");

    open(OUT, ">dbk.sql");
    select(OUT);

    print("-- Dagboeken\n\n",
	  "COPY Dagboeken FROM stdin;\n");
    my %dbmap = ("Kas" => 4,
		 "Bank/Giro" => 3,
		 "Inkoop" => 1,
		 "Verkoop" => 2,
		 "Memoriaal" => 5 );

    for ( my $i = 0; $i < @dagboeken; $i++ ) {
	next unless exists $dagboeken[$i];
	my $db = $dagboeken[$i];
	print(join("\t", $i, $db->[0], $dbmap{$db->[1]}, $db->[2]), "\n");
    }
    print("\\.\n\n");

    print("-- Sequences for Boekstuknummers, one for each Dagboek\n\n");

    for ( my $i = 0; $i < @dagboeken; $i++ ) {
	next unless exists $dagboeken[$i];
	print("CREATE SEQUENCE bsk_nr_${i}_seq;\n");
    }
    print("\n");

    close(OUT);
    select(STDOUT);

    open(OUT, ">open.dat");

    print OUT ("# Data voor openingsbalans:\n\n");
    foreach ( @transactions ) {
	print OUT ("@$_\n");
    }

    close(OUT)

}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally
    my $man = 0;		# handled locally

    # Process options.
    if ( @ARGV > 0 ) {
	GetOptions('ident'	=> \$ident,
		   'verbose'	=> \$verbose,
		   'trace'	=> \$trace,
		   'help|?'	=> \$help,
		   'man'	=> \$man,
		   'debug'	=> \$debug)
	  or pod2usage(2);
    }
    if ( $ident or $help or $man ) {
	print STDERR ("This is $my_package [$my_name $my_version]\n");
    }
    if ( $man or $help ) {
	# Load Pod::Usage only if needed.
	require "Pod/Usage.pm";
	import Pod::Usage;
	pod2usage(1) if $help;
	pod2usage(VERBOSE => 2) if $man;
    }
}

__END__

################ Documentation ################

=head1 NAME

sample - skeleton for GetOpt::Long and Pod::Usage

=head1 SYNOPSIS

sample [options] [file ...]

 Options:
   -ident		show identification
   -help		brief help message
   -man                 full documentation
   -verbose		verbose information

=head1 OPTIONS

=over 8

=item B<-help>

Print a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=item B<-ident>

Prints program identification.

=item B<-verbose>

More verbose information.

=item I<file>

Input file(s).

=back

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do someting
useful with the contents thereof.

=cut
