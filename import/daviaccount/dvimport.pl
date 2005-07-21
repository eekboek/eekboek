#!/usr/bin/perl -w
my $RCS_Id = '$Id: dvimport.pl,v 1.6 2005/07/21 10:26:55 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : June 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 21 12:23:50 2005
# Update Count    : 221
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

use EB::Globals;
use EB::Finance;

read_exact_data();

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


sub read_dagboeken {
    my @dagboeken;
    while ( <$db> ) {
	last unless $_ =~ /\S/;
	# 1     Kas                                      Kas                 1000
	my @a = unpack("a6a41a20a6", $_);
	for ( @a[1,2] ) {
	    s/\s+$//;
	}
	$dagboeken[0+$a[0]] = [ @a[1,2], $a[3] eq "N.v.t." ? "\\N" : 0+$a[3] ];
    }

    open(my $f, ">dbk.sql") or die("Cannot create dbk.sql: $!\n");

    print $f ("-- Dagboeken\n\n",
	      "COPY Dagboeken FROM stdin;\n");
    my %dbmap = ("Kas"	      => DBKTYPE_KAS,
		 "Bank/Giro"  => DBKTYPE_BANK,
		 "Inkoop"     => DBKTYPE_INKOOP,
		 "Verkoop"    => DBKTYPE_VERKOOP,
		 "Memoriaal"  => DBKTYPE_MEMORIAAL );

    for ( my $i = 0; $i < @dagboeken; $i++ ) {
	next unless exists $dagboeken[$i];
	my $db = $dagboeken[$i];
	print $f (join("\t", $i, $db->[0], $dbmap{$db->[1]}, $db->[2]), "\n");
    }
    print $f ("\\.\n\n");

    print $f("-- Sequences for Boekstuknummers, one for each Dagboek\n\n");

    for ( my $i = 0; $i < @dagboeken; $i++ ) {
	next unless exists $dagboeken[$i];
	print $f ("CREATE SEQUENCE bsk_nr_${i}_seq;\n");
    }
    print $f ("\n");
    close($f);
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

sub read_btw {
    my $hi;
    my $lo;
    my $btw_acc_hi_i;
    my $btw_acc_hi_v;
    my $btw_acc_lo_i;
    my $btw_acc_lo_v;
   my @btwtable;

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
	next unless $btw;

	if ( $btw == $hi ) {
	    if ( $btw_acc_hi_i && ($btw_acc_hi_i != $a[4] || $btw_acc_hi_v != $a[5]) ) {
		warn("BTW probleem 1\n");
	    }
	    else {
		$btw_acc_hi_i = 0+$a[4];
		$btw_acc_hi_v = 0+$a[5];
	    }
	}
	elsif ( $btw == $lo ) {
	    if ( $btw_acc_lo_i && ($btw_acc_lo_i != $a[4] || $btw_acc_lo_v != $a[5]) ) {
		warn("BTW probleem 2\n");
	    }
	    else {
		$btw_acc_lo_i = 0+$a[4];
		$btw_acc_lo_v = 0+$a[5];
	    }
	}
    }
    foreach ( @btwtable ) {
	push(@$_, $_->[1] == 0 ? BTWTYPE_GEEN :
	     $_->[1] == $hi ? BTWTYPE_HOOG :
	     $_->[1] == $lo ? BTWTYPE_LAAG : warn("Onbekende BTW group: $_->[1]\n"));
    }

    open(my $f, ">btw.sql") or die("Cannot create btw.sql: $!\n");

    print $f ("-- BTW Tariefgroepen\n\n",
	      "COPY BTWTariefgroepen (btg_id, btg_desc, btg_acc_verkoop, btg_acc_inkoop) FROM stdin;\n",
	      "@{[BTWTYPE_GEEN]}\tBTW Geen\t\\N\t\\N\n",
	      "@{[BTWTYPE_HOOG]}\tBTW Hoog\t$btw_acc_hi_v\t$btw_acc_hi_i\n",
	      "@{[BTWTYPE_LAAG]}\tBTW Laag\t$btw_acc_lo_v\t$btw_acc_lo_i\n",
	      "\\.\n\n");

    print $f ("-- BTW Tabel\n\n",
	      "COPY BTWTabel (btw_id, btw_desc, btw_perc, btw_incl, btw_tariefgroep) FROM stdin;\n");

    for ( my $i = 0; $i < @btwtable; $i++ ) {
	next unless exists $btwtable[$i];
	my $b = $btwtable[$i];
	print $f (join("\t", $i, @$b), "\n");
    }

    print $f ("\\.\n\n");
    close($f);

}

sub write_rekeningschema {

    open(my $f, ">vrd.sql") or die("Cannot create vrd.sql: $!\n");

    print $f ("-- Hoofdverdichtingen\n\n",
	      "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct)".
	      " FROM stdin;\n");
    for ( my $i = 0; $i < @hoofdverdichtingen; $i++ ) {
	next unless exists $hoofdverdichtingen[$i];
	my $v = $hoofdverdichtingen[$i];
	# Skip unused verdichtingen.
	next unless defined($v->[1]) && defined($v->[2]);
	print $f (join("\t", $i,
		       $v->[0],
		       $v->[1] eq 'B' ? 't' : 'f',
		       $v->[2] eq 'N' ? 't' : 'f',
		       "\\N"), "\n");
    }
    print $f ("\\.\n\n");

    print $f ("-- Verdichtingen\n\n",
	      "COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;\n");
    for ( my $i = 0; $i < @verdichtingen; $i++ ) {
	next unless exists $verdichtingen[$i];
	my $v = $verdichtingen[$i];
	# Skip unused verdichtingen.
	next unless defined($v->[1]) && defined($v->[2]);
	print $f (join("\t", $i,
		       $v->[0],
		       $v->[1] eq 'B' ? 't' : $v->[1] eq 'W' ? 'f' : '?',
		       $v->[2] eq 'N' ? 't' : $v->[2] eq 'J' ? 'f' : '?',
		       $v->[3]), "\n");
    }
    print $f ("\\.\n\n");
    close($f);

    open($f, ">acc.sql") or die("Cannot create acc.sql: $!\n");

    print $f ("-- Grootboekrekeningen\n\n",
	      "COPY Accounts (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd,".
	      " acc_kstomz, acc_btw, acc_ibalance, acc_balance) FROM stdin;\n");

    for my $i ( sort { $a <=> $b } keys(%grootboek) ) {
	my $g = $grootboek{$i};
	# desc B/W D/C N/.. struct btw N/J(omzet)?
	print $f (join("\t", $i,
		       $g->[0],
		       $g->[4],
		       $g->[1] eq 'B' ? 't' : 'f',
		       $g->[2] eq 'D' ? 't' : 'f',
		       $g->[6] eq 'N' ? 't' : 'f',
		       $g->[5],
		       0,
		       0), "\n");
    }
    print $f ("\\.\n\n");
    close($f);

    open($f, ">open.dat") or die("Cannot create open.dat: $!\n");

    print $f ("# Data voor openingsbalans:\n\n");
    foreach ( @transactions ) {
	print $f ("@$_\n");
    }

    close($f)

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
