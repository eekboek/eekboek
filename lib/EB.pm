# EB.pm -- 
# RCS Info        : $Id: EB.pm,v 1.22 2005/12/12 11:29:29 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep 16 18:38:45 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Dec 12 12:29:26 2005
# Update Count    : 88
# Status          : Unknown, Use with caution!

our $app;

package EB;

use strict;
use base qw(Exporter);

our $VERSION;
$VERSION = "0.21";

our @EXPORT;
our @EXPORT_OK;

# Establish location of our data, relative to this module.
my $lib;
BEGIN {
    $lib = $INC{"EB.pm"};
    $lib =~ s/EB\.pm$//;
    $ENV{EB_LIB} = $lib;
    # warn("lib = $lib\n");
}

# Make it accessible.
sub EB_LIB() { $lib }

# Some standard modules.
use EB::Globals;

BEGIN {
    # The core and GUI use a different EB::Locale module.
    if ( $app ) {
	require EB::Wx::Locale;
    }
    else {
	require EB::Locale;
    }
    EB::Locale::->import;
}

# Utilities.
use EB::Utils;

# Export our and the imported globals.
BEGIN {
    @EXPORT = ( qw(EB_LIB),
		@EB::Globals::EXPORT,
		@EB::Utils::EXPORT,
		@EB::Locale::EXPORT,
	      );
}

our @months;
our @month_names;
our @days;
our @day_names;
our $ident;
our $url = "http://www.squirrel.nl/eekboek";

INIT {
    # Banner. Wow! Static code!
    my $year = 2005;
    my $thisyear = (localtime(time))[5] + 1900;
    $year .= "-$thisyear" unless $year == $thisyear;
    $ident = __x("EekBoek {version}", version => $VERSION);
    warn(__x("{ident} {extra}{locale}-- Copyright {year} Squirrel Consultancy",
		 ident   => $ident,
		 extra   => ($app ? "Wx " : ""),
		 locale  => (LOCALISER ? "("._T("Nederlands").") " : ""),
		 year    => $year)."\n");
    @months =
      split(" ", _T("Jan Feb Mrt Apr Mei Jun Jul Aug Sep Okt Nov Dec"));
    @month_names =
      split(" ", _T("Januari Februari Maart April Mei Juni Juli Augustus September Oktober November December"));
    @days =
      split(" ", _T("Zon Maa Din Woe Don Vri Zat"));
    @day_names =
      split(" ", _T("Zondag Maandag Dinsdag Woensdag Donderdag Vrijdag Zaterdag"));
}

1;
