#!/usr/bin/perl

package EB::Utils;

use strict;

use base qw(Exporter);

our @EXPORT;
our @EXPORT_OK;

use Time::Local;

sub parse_date {
    my ($date, $default_year) = @_;

    # Parse a date and return it in ISO format (scalar) o
    # r (YYYY,MM,DD) list context.

    my ($d, $m, $y);
    if ( $date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/ ) {
	($y, $m, $d) = ($1, $2, $3);
    }
    elsif ( $date =~ /^(\d\d)-(\d\d)-(\d\d\d\d)$/ ) {
	($d, $m, $y) = ($1, $2, $3);
    }
    elsif ( $date =~ /^(\d\d)-(\d\d)$/ ) {
	($d, $m, $y) = ($1, $2, $default_year);
    }
    else {
	return;		# invalid format
    }
    my $time = eval { timelocal(0, 0, 0, $d, $m-1, $y) };
    return unless $time;	# invalid date
    my @tm = localtime($time);
    @tm = (1900 + $tm[5], 1 + $tm[4], $tm[3]);
    wantarray ? @tm : sprintf("%04d-%02d-%02d", @tm);
}

BEGIN { push(@EXPORT, qw(parse_date)) }








BEGIN { @EXPORT_OK = @EXPORT }

1;
