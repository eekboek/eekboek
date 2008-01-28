#!/usr/bin/perl

package EB::Utils;

use strict;

use base qw(Exporter);

our @EXPORT;
our @EXPORT_OK;

use Time::Local;

my %rev_months;
my %rev_month_names;

sub parse_date {
    my ($date, $default_year, $delta_d, $delta_m, $delta_y) = @_;

    # Parse a date and return it in ISO format (scalar) or
    # (YYYY,MM,DD) list context.

    my ($d, $m, $y);
    if ( $date =~ /^(\d\d\d\d)-(\d\d)-(\d\d)$/ ) {
	($y, $m, $d) = ($1, $2, $3);
    }
    elsif ( $date =~ /^(\d\d?)-(\d\d?)-(\d\d\d\d)$/ ) {
	($d, $m, $y) = ($1, $2, $3);
    }
    elsif ( $date =~ /^(\d\d?)-(\d\d?)$/ ) {
	($d, $m, $y) = ($1, $2, $default_year);
    }
    elsif ( $date =~ /^(\d\d?) (\w+)$/ ) {
	unless ( %rev_months ) {
	    my $i = 1;
	    foreach ( @EB::months ) {
		$rev_months{lc $_} = $i;
		$rev_months{"m$i"} = $i;
		$rev_months{sprintf("m%02d", $i)} = $i;
		$i++;
	    }
	    $i = 1;
	    foreach ( @EB::month_names ) {
		$rev_month_names{lc $_} = $i++;
	    }
	}
	return unless $default_year;
	return unless $m = $rev_month_names{$2} || $rev_months{$2};
	($d, $y) = ($1, $default_year);
    }
    else {
	return;		# invalid format
    }
    $y = $y + $delta_y if $delta_y;
    $m = $m + $delta_m if $delta_m;
    $m = 1, $y++ if $m > 12;
    $m = 12, $y-- if $m < 0;
    my $time = eval { timelocal(0, 0, 0, $d, $m-1, $y) };
    return unless $time;	# invalid date
    $time += $delta_d * 24*60*60 if $delta_d;
    my @tm = localtime($time);
    @tm = (1900 + $tm[5], 1 + $tm[4], $tm[3]);
    wantarray ? @tm : sprintf("%04d-%02d-%02d", @tm);
}

BEGIN { push(@EXPORT, qw(parse_date)) }

sub parse_date_range {
    my ($range, $default_year) = @_;

    # Parse a date and return it as an array ref of two ISO formatted
    # dates.

    my ($d1, $m1, $y1, $d2, $m2, $y2);
    my $datefix;

    unless ( %rev_months ) {
	my $i = 1;
	foreach ( @EB::months ) {
	    $rev_months{lc $_} = $i;
	    $rev_months{"m$i"} = $i;
	    $rev_months{sprintf("m%02d", $i)} = $i;
	    $i++;
	}
	$i = 1;
	foreach ( @EB::month_names ) {
	    $rev_month_names{lc $_} = $i++;
	}
    }

    $range = lc($range);

    # 2004-03-04 - 2004-05-06 -> [ "2004-03-04", "2004-05-06" ]
    if ( $range =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s*[-\/]\s*(\d\d\d\d)-(\d\d)-(\d\d)$/ ) {
	($y1, $m1, $d1, $y2, $m2, $d2) = ($1, $2, $3, $4, $5, $6);
    }
    # 2004-03-04/05-06 -> [ "2004-03-04", "2004-05-06" ]
    elsif ( $range =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s*\/\s*(\d\d)-(\d\d)$/ ) {
	($y1, $m1, $d1, $y2, $m2, $d2) = ($1, $2, $3, $1, $4, $5);
    }
    # 2004-03-04/06 -> [ "2004-03-04", "2004-03-06" ]
    elsif ( $range =~ /^(\d\d\d\d)-(\d\d)-(\d\d)\s*\/\s*(\d\d)$/ ) {
	($y1, $m1, $d1, $y2, $m2, $d2) = ($1, $2, $3, $1, $2, $4);
    }
    # 03-04-2004 - 05-06-2004 -> [ "2004-04-03", "2004-06-05" ]
    elsif ( $range =~ /^(\d\d)-(\d\d)-(\d\d\d\d)\s*-\s*(\d\d)-(\d\d)-(\d\d\d\d)$/ ) {
	($d1, $m1, $y1, $d2, $m2, $y2) = ($1, $2, $3, $4, $5, $6);
    }
    # 03-04 - 05-06 -> [ "2004-04-03", "2004-06-25" ]
    elsif ( $range =~ /^(\d\d)-(\d\d)\s*-\s*(\d\d)-(\d\d)$/ ) {
	return unless $default_year;
	($d1, $m1, $y1, $d2, $m2, $y2) = ($1, $2, $default_year, $3, $4, $default_year);
    }
    # 3 april - 5 juni -> [ "2004-04-03", "2004-06-25" ]
    # 3 april - 5 juni 2004 -> [ "2004-04-03", "2004-06-25" ]
    elsif ( $range =~ /^(\d+)\s+(\w+)\s*-\s*(\d+)\s+(\w+)(?:\s+(\d{4}))?$/ ) {
	return unless $default_year;
	return unless $m1 = $rev_month_names{$2} || $rev_months{$2};
	return unless $m2 = $rev_month_names{$4} || $rev_months{$4};
	$d1 = $1; $d2 = $3;
	$y1 = $y2 = $5 || $default_year;
    }
    # 3 april 2004 - 5 juni 2004 -> [ "2004-04-03", "2004-06-25" ]
    elsif ( $range =~ /^(\d+)\s+(\w+)\s+(\d{4})\s*-\s*(\d+)\s+(\w+)\s+(\d{4})$/ ) {
	return unless $m1 = $rev_month_names{$2} || $rev_months{$2};
	return unless $m2 = $rev_month_names{$5} || $rev_months{$5};
	$d1 = $1; $d2 = $4;
	$y1 = $3; $y2 = $6;
    }
    # april - juni -> [ "2004-04-01", "2004-06-30" ]
    # april - juni 2004 -> [ "2004-04-01", "2004-06-30" ]
    elsif ( $range =~ /^(\w+)\s*-\s*(\w+)(?:\s+(\d{4}))?$/ ) {
	return unless $default_year;
	return unless $m1 = $rev_month_names{$1} || $rev_months{$1};
	return unless $m2 = $rev_month_names{$2} || $rev_months{$2};
	$d1 = 1; $d2 = -1;
	$y1 = $y2 = $3 || $default_year;
    }
    # 2004          -> [ "2004-01-01", "2004-12-31" ]
    elsif ( $range =~ /^(\d{4})$/ ) {
	$d1 = 1; $d2 = -1; $m1 = 1; $m2 = 12; $y1 = $y2 = $1;
    }
    # k2 -> [ "2004-04-01", "2004-06-30" ]
    # k2 2004 -> [ "2004-04-01", "2004-06-30" ]
    elsif ( $range =~ /^[kq](\d+)(?:\s+(\d{4}))?$/ ) {
	return unless $2||$default_year;
	return unless $1 >= 1 && $1 <= 4;
	$m1 = 3 * $1 - 2;
	$m2 = $m1 + 2;
	$d1 = 1; $d2 = -1; $y1 = $y2 = $2 || $default_year;
    }
    # jaar          -> [ "2004-01-01", "2004-12-31" ]
    elsif ( $range eq lc(EB::_T("jaar")) || $range eq "jaar" ) {
	return unless $default_year;
	$d1 = 1; $d2 = -1; $m1 = 1; $m2 = 12; $y1 = $y2 = $default_year;
    }
    # apr | april   -> [ "2004-04-01", "2004-04-30" ]
    # apr 2004      -> [ "2004-04-01", "2004-04-30" ]
    elsif ( $range =~ /^(\w+)(?:\s+(\d{4}))?$/ ) {
	return unless $2||$default_year;
	return unless $m1 = $m2 = $rev_month_names{$1} || $rev_months{$1};
	$d1 = 1; $d2 = -1;
	$y1 = $y2 = $2 || $default_year;
    }
    else {
	return;		# unrecognizable format
    }

    if ( $d2 < 0 ) {
	$datefix = 24 * 60 * 60;
	$d2 = 1;
	$m2 = 1, $y2++ if ++$m2 > 12;
    }

    my $time1 = eval { timelocal(0, 0, 0, $d1, $m1-1, $y1) };
    return unless $time1;	# invalid date
    my $time2 = eval { timelocal(0, 0, 0, $d2, $m2-1, $y2) };
    return unless $time2;	# invalid date
    $time2 -= $datefix if $datefix;

    my @tm = localtime($time1);
    my @tm1 = (1900 + $tm[5], 1 + $tm[4], $tm[3]);
    @tm = localtime($time2);
    my @tm2 = (1900 + $tm[5], 1 + $tm[4], $tm[3]);
    [ sprintf("%04d-%02d-%02d", @tm1),
      sprintf("%04d-%02d-%02d", @tm2) ]
}

BEGIN { push(@EXPORT, qw(parse_date_range)) }

sub iso8601date {
    my ($time) = shift || time;
    my @tm = localtime($time);
    sprintf("%04d-%02d-%02d", 1900+$tm[5], 1+$tm[4], $tm[3]);
}

BEGIN { push(@EXPORT, qw(iso8601date)) }

# ... more to come ...

BEGIN { @EXPORT_OK = @EXPORT }

1;
