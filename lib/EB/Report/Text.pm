#!/usr/bin/perl -w
my $RCS_Id = '$Id: Text.pm,v 1.1 2005/07/14 12:54:08 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jul  9 21:43:50 2005
# Update Count    : 99
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Report::Text;

use strict;
use warnings;

use EB::Globals;
use EB::Finance;

sub new {
    bless {};
}

my $fmt = "%-6s  %-40.40s  %9s  %9s\n";

sub addline {
    my ($self, $type, $acc, $desc, $deb, $crd) = @_;
    if ( $type eq 'H' ) {
	print($desc, "\n\n") if $desc;
	my $hdr = sprintf($fmt, "RekNr", "Grootboekrekening", "Debet", "Credit");
	print($hdr);
	$hdr =~ tr/\n/-/c;
	print($hdr);
	return;
    }
    if ( $type eq 'T' ) {
	my $hdr = sprintf($fmt, "RekNr", "Grootboekrekening", "Debet", "Credit");
	$hdr =~ tr/\n/-/c;
	print($hdr);
    }
    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd ) {
	$_ = $_ ? numfmt($_) : '';
    }
    if ( $type =~ /^D(\d+)/ ) {
	$desc = (" " x $1) . $desc;
    }
    elsif ( $type =~ /^[HT](\d+)/ ) {
	$desc = (" " x ($1-1)) . $desc;
    }
    printf($fmt, $acc, $desc, $deb, $crd);
# TODO   print("\n") if $detail > 0 && $type =~ /^T\d+$/;
    print("\n") if $type =~ /^T\d+$/;
}
