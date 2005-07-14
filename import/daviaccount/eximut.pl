#!/usr/bin/perl -w
my $RCS_Id = '$Id: eximut.pl,v 1.2 2005/07/14 19:39:42 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Fri Jun 17 21:31:52 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jul 14 15:05:24 2005
# Update Count    : 130
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;

# Package or program libraries, if appropriate.
# $LIBDIR = $ENV{'LIBDIR'} || '/usr/local/lib/sample';
# use lib qw($LIBDIR);
# require 'common.pl';

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

use EB::DB;

our $trace = $ENV{EB_SQL_TRACE};

our $dbh = EB::DB->new(trace => $trace);

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use Text::CSV_XS;

@ARGV = ("FMUTA6.CSV") unless @ARGV;

my @fieldnames0;
my @fieldnames;
my $f = \@fieldnames0;
while ( <DATA> ) {
    next if /^#/;
    $f = \@fieldnames, next unless /\S/;
    my @a = split(/\t/);
    push(@$f, $a[1]);
}

my @dagboeken;
my $sth = $dbh->sql_exec("SELECT dbk_id,dbk_desc FROM Dagboeken");
my $rr;
while ( $rr = $sth->fetchrow_arrayref ) {
    $dagboeken[$rr->[0]] = lc($rr->[1]);
}

my $csv = new Text::CSV_XS ({binary => 1});
open (my $db, $ARGV[0])
  or die("Missing: $ARGV[0]\n");

# Collect and split into IV and others.
# This is to prevent BGK bookings to preceede the corresponding IV booking.
my @prim;
my @sec;
while ( <$db> ) {
    $csv->parse($_);
    my @a = $csv->fields();
    if ( $a[1] =~ /^[iv]$/i ) {
	push(@prim, [@a]);
    }
    else {
	push(@sec, [@a]);
    }
}

# Process bookings.
my $mut;
foreach ( @prim, @sec) {
    my @a = @$_;
    my %a;
    if ( $a[0] == 0 ) {
	flush($mut) if $mut;
	@a{@fieldnames0} = @a;
	$mut = [ \%a ];
	next;
    }
    @a{@fieldnames} = @a;
    warn("OOPS: $a[0] should be " . scalar(@$mut) . "\n")
      unless $a[0] == @$mut;
    push(@$mut, \%a);

}
flush($mut) if $mut;

sub flush {
    my ($mut) = @_;
    my $r0 = shift(@$mut);
    my $dbk = $r0->{dagbknr};
    my $dbktype = $r0->{dagb_type};

    if ( $dbktype eq 'I' ) {	# Inkoop
	print($dagboeken[$dbk], " ", dd($mut->[0]->{Date}),
	      ' "' . uc($r0->{crdnr}) . '"');
	foreach my $r ( @$mut ) {
	    print join(" ", "", '"' . $r->{oms25} . '"',
		       (debcrd($r->{reknr}) ? $r->{bedrag} : 0-$r->{bedrag}).
		       fixbtw($r),
		       $r->{reknr});
	}
	print("\n");
    }
    elsif ( $dbktype eq 'V' ) {	# Verkoop
	print($dagboeken[$dbk], " ", dd($mut->[0]->{Date}),
	      ' "' . uc($r0->{debnr}) . '"');
	foreach my $r ( @$mut ) {
	    print join(" ", "", '"' . $r->{oms25} . '"',
		       (debcrd($r->{reknr}) ? $r->{bedrag} : 0-$r->{bedrag}).
		       fixbtw($r),
		       $r->{reknr});
	}
	print("\n");
    }
#    elsif ( $dbktype eq 'M' ) {	# Memoriaal
#	return unless @$mut;
#	print($dagboeken[$dbk], " ", dd($mut->[0]->{Date}));
#	foreach my $r ( @$mut ) {
#	    print join(" ", "",
#		       '"' . $r->{oms25} . '"',
#		       debcrd($r->{reknr}) ? $r->{bedrag} : 0-$r->{bedrag},
#		       $r->{reknr});
#	}
#	print("\n");
#    }
    elsif ( $dbktype =~ /^[GBKM]$/ ) {	# Bank/Giro/Kas/Memoriaal;
	return unless @$mut;
	print($dagboeken[$dbk], " ", dd($mut->[0]->{Date}), ' "', $r0->{oms25} ||"Diverse boekingen", '"');
	foreach my $r ( @$mut ) {
	    if ( $r->{crdnr} ) {
		print join(" ", " crd",
			   '"'.uc($r->{crdnr}).'"',
			   sprintf("%.2f", $r->{bedrag}),
			  );
	    }
	    elsif ( $r->{debnr} ) {
		print join(" ", " deb",
			   '"'.uc($r->{debnr}).'"',
			   sprintf("%.2f", 0-$r->{bedrag}),
			  );
	    }
	    else {
		print join(" ", " std",
			   '"'.$r->{oms25}.'"',
			   sprintf("%.2f",
				   debcrd($r->{reknr}) ? $r->{bedrag} : 0-$r->{bedrag}).
			   fixbtw($r),
			   $r->{reknr},
			  );
	    }
	}
	print("\n");
    }

    #use Data::Dumper;
    #print Dumper($mut);
    #exit;
}

sub fixbtw {
    # Correctie BTW code indien niet conform de grootboekrekening.
    my $r = shift;
    my $b = $r->{btw_code};
    return "" if $b eq "";

    # Het lijkt erop dat FMUTA6.CSV altijd alle bedragen inclusief BTW opneemt.
    # warn("!!! BTW CODE EXCL --- CHECK !!!\n") if $b == 2 || $b == 4;
    $b-- if $b == 2 || $b == 4;

    my $br = btw_code($r->{reknr});
    return "" if $b == $br;

    '@'.$b;
}

sub dd {
    my ($date) = @_;

    # Kantelpunt is willekeurig gekozen.
    sprintf("%04d-%02d-%02d",
	    $3 < 90 ? 2000 + $3 : 1900 + $3, $2, $1)
      if $date =~ /^(\d\d)(\d\d)(\d\d)$/;
}
exit 0;

################ Subroutines ################

my %debcrd;
sub debcrd {
    my($acct) = @_;
    return $debcrd{$acct} if defined $debcrd{$acct};
    _lku($acct);
    $debcrd{$acct};
}

my %btw_code;
sub btw_code {
    my($acct) = @_;
    return $btw_code{$acct} if defined $btw_code{$acct};
    _lku($acct);
    $btw_code{$acct};
}

my %kstomz;
sub kstomz {
    my($acct) = @_;
    return $kstomz{$acct} if defined $kstomz{$acct};
    _lku($acct);
    $kstomz{$acct};
}

sub _lku {
    my ($acct) = @_;
    my $rr = $dbh->do("SELECT acc_debcrd,acc_kstomz,acc_btw".
		      " FROM Accounts".
		      " WHERE acc_id = ?", $acct);
    die("Onbekend rekeningnummer $acct\n")
      unless $rr;
    $debcrd{$acct} = $rr->[0];
    $kstomz{$acct} = $rr->[1];
    $btw_code{$acct} = $rr->[2];
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    if ( !GetOptions(
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
__END__
# http://www.exact.nl/docs/BDDocument.asp?Action=VIEW&ID=%7B2E238404%2DB177%2D4444%2DA192%2DEF8C037D5704%7D
1	regelnummer	Regelnummer	Number	 Verplicht	N3
2	dagb_type	Dagboektype	Text	 Verplicht	A1
3	dagbknr	Dagboek	Numstr	 Verplicht	A3
4	periode	Periode	Numstr	 niet gebr	A3
5	bkjrcode	Boekjaar	Numstr	 niet gebr	A2
6	bkstnr	Boekstuknummer	Numstr		A8
7	oms25	Omschrijving	Text		A60
8	Date	Datum	Date		A8
9	Empty	-			A9
10	debnr	Debiteur	Numstr	 verkoop	A6
11	crdnr	Crediteur	Numstr	 inkoop	A6
12	Empty	-			A8
13	bedrag	Bedrag	Number	 niet gebr	N8.2
14	drbk_in_val	Journaliseren in VV	Text		A1
15	valcode	Valuta (optioneel)	Text		A3
16	koers	Wisselkoers (optioneel)	Number		N5.6
17	kredbep	Kredietbeperking / Betalingskorting	Text		A1
18	bdrkredbep	Bedrag Kredietbeperking / Betalingskorting	Number		N8.2
19	vervdatfak	Vervaldatum factuur	Date		A8
20	vervdatkrd	Vervaldatum Kredietbeperking / Betalingskorting	Date		A8
21	Empty	-			A3
22	Empty	-			N8.2
23	weeknummer	Weeknummer	Numstr	 niet gebr	A2
24	betaalref	Betaalreferentie	Text		A20
25	betwijze	Betaalwijze	Text		A1
26	grek_bdr	Bedrag G-rekening	Number		N8.2
27	Empty	-			A4
28	Empty	-			A4
29	Empty	-			8.2
30	Empty	-			A1
31	Empty	-			A2
32	storno	Stornoboeking	Text		A1
33	Empty	-			A8
34	Empty	-			N8.2
35	Empty	-			N8.2
36	Empty	-			N6.2
37	Empty	-			N6.2
38	Empty	-			A8
39	Empty	-			A25
40	Empty	-		 Verplicht	A8

1	regelnummer	regelnummer	Number	 Verplicht	N3
2	dagb_type	Dagboektype	Text	 Verplicht	A1
3	dagbknr	Dagboek	Numstr	 Verplicht	A3
4	periode	Periode	Numstr	 niet gebr	A3
5	bkjrcode	Boekjaar	Numstr	 niet gebr	A2
6	bkstnr	Boekstuknummer	Numstr		A8
7	oms25	Omschrijving	Text		A60
8	Date	Datum	Date		A8
9	reknr	Grootboekrekening	Numstr	 Verplicht	A9
10	debnr	Debiteur	Numstr	 Memoriaal	A6
11	crdnr	Crediteur	Numstr	 Memoriaal	A6
12	faktuurnr	Onze referentie	Numstr		A8
13	bedrag	Bedrag	Number	 Verplicht	N8.2
14	Empty	-			A1
15	valcode	Valuta	Text		A3
16	koers	Wisselkoers	Number		N5.6
17	Empty	-			A1
18	Empty	-			N8.2
19	Empty	-			A8
20	Empty	-			A8
21	btw_code	BTW-code	Text		A3
22	btw_bdr	BTW-bedrag	Number		N8.2
23	Empty	-			A2
24	Empty	-			A20
25	Empty	-			A1
26	Empty	-			N8.2
27	kstplcode	Kostenplaatscode	Text		A8
28	kstdrcode	Kostendragercode	Text		A8
29	aantal	Aantal	Number		N8.2
30	Empty	-			A1
31	Empty	-			A2
32	storno	Stornoboeking	Text		A1
33	Empty	-			A8
34	Empty	-			N8.2
35	Empty	-			N8.2
36	Empty	-			N6.2
37	Empty	-			N6.2
38	Empty	-			A8
39	Empty	-			A25
40	Empty	-		 Verplicht	A8
