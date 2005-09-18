#!/usr/bin/perl -w
my $RCS_Id = '$Id: Text.pm,v 1.4 2005/09/18 21:07:57 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Sep 18 21:40:34 2005
# Update Count    : 121
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Report::Text;

use strict;
use warnings;

use EB;
use EB::Finance;

my $fmt = "%-6s  %-40.40s  %9s  %9s  %9s  %9s\n";

sub new {
    my $class = shift;
    my $self = { @_ };

    $self->{hdr} =
      sprintf($fmt, _T("RekNr"),
	      $self->{verdicht} ? _T("Verdichting/Grootboekrekening") : _T("Grootboekrekening"),
	      _T("Debet"), _T("Credit"),
	      $self->{proef} ? (_T("Saldo Db"), _T("Saldo Cr")) : ('', '')
	     );
    $self->{hdr} =~ s/ +$//;
    ($self->{line} = $self->{hdr}) =~ tr/\n/-/c;

    bless $self, $class;
}

sub addline {
    my ($self, $type, $acc, $desc, $deb, $crd, $sdeb, $scrd) = @_;
    if ( $type eq 'H' ) {
	print($desc, "\n\n") if $desc;
	print($self->{hdr});
	print($self->{line});
	return;
    }
    if ( $type eq 'T' ) {
	print($self->{line});
    }
    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd, $sdeb, $scrd ) {
	$_ = $_ ? numfmt($_) : '';
    }
    if ( $type =~ /^D(\d+)/ ) {
	$desc = (" " x $1) . $desc;
    }
    elsif ( $type =~ /^[HT](\d+)/ ) {
	$desc = (" " x ($1-1)) . $desc;
    }
    my $t = sprintf($fmt, $acc, $desc, $deb, $crd, $sdeb, $scrd);
    $t =~ s/ +$//;
    print($t);
    print("\n") if $type =~ /^T(\d+)$/ && $1 <= $self->{detail};
}

sub finish {
}

1;
