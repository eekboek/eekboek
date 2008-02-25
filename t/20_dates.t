#! perl
# $Id: 20_dates.t,v 1.3 2008/02/25 11:50:00 jv Exp $

use strict;
use warnings;

use EB::Config qw(EekBoek);
use EB;

my @tests1;
my @tests2;
BEGIN {
    @tests1 =
      (
	"01-02"				=> "2004-02-01",
	"01-02-2003"			=> "2003-02-01",
	"2003-02-01"			=> "2003-02-01",
      );
    @tests2 =
      (
       "jaar"				=> "2004-01-01 - 2004-12-31",
       "2003-03-04 - 2003-05-06"	=> "2003-03-04 - 2003-05-06",
       "2003-03-04 / 2003-05-06"	=> "2003-03-04 - 2003-05-06",
       "2003-03-04 / 05-06"		=> "2003-03-04 - 2003-05-06",
       "2003-03-04 / 06"		=> "2003-03-04 - 2003-03-06",
       "03-04-2003 - 05-06-2003"	=> "2003-04-03 - 2003-06-05",
       "03-04 - 25-06"			=> "2004-04-03 - 2004-06-25",
       "3 april - 25 jun"		=> "2004-04-03 - 2004-06-25",
       "3 april - 25 jun 2003"		=> "2003-04-03 - 2003-06-25",
       "3 april 2003 - 25 jun 2003"	=> "2003-04-03 - 2003-06-25",
       "april - jun"			=> "2004-04-01 - 2004-06-30",
       "april - jun 2003"		=> "2003-04-01 - 2003-06-30",
       "k2"				=> "2004-04-01 - 2004-06-30",
       "k2 2003"			=> "2003-04-01 - 2003-06-30",
       "jaar"				=> "2004-01-01 - 2004-12-31",
       "apr"				=> "2004-04-01 - 2004-04-30",
       "april"				=> "2004-04-01 - 2004-04-30",
       "m4"				=> "2004-04-01 - 2004-04-30",
       "m04"				=> "2004-04-01 - 2004-04-30",
       "apr 2003"			=> "2003-04-01 - 2003-04-30",
       "m04 2003"			=> "2003-04-01 - 2003-04-30",
       "2003"				=> "2003-01-01 - 2003-12-31",
      );
}

use Test::More tests => @tests1 + @tests2/2;

# Test date parsing.
while ( @tests1 ) {
    my $date = shift(@tests1);
    my $exp = shift(@tests1);
    my $res = parse_date($date, 2004);
    #ok(1, "$date -> undef"), next unless $exp || $res;
    is($res, $exp, "date $date");
    my @res = parse_date($date, 2004);
    $res = sprintf("%04d-%02d-%02d", @res);
    is($res, $exp, "date $date");
}

# Test range parsing.
while ( @tests2 ) {
    my $range = shift(@tests2);
    my $exp = shift(@tests2);
    my $res = parse_date_range($range, 2004);
    #ok(1, "$range -> undef"), next unless $exp || $res;
    $res = defined($res) ? join(" - ", @$res) : "<undef>";
    is($res, $exp, "range $range");
}
