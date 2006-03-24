# EB.pm -- 
# RCS Info        : $Id: EB.pm,v 1.57 2006/03/24 13:53:07 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep 16 18:38:45 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar 24 13:34:48 2006
# Update Count    : 132
# Status          : Unknown, Use with caution!

our $app;

package EB;

use strict;
use base qw(Exporter);

our $VERSION;
$VERSION = "0.51";

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
use Carp;
use Data::Dumper;

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
		qw(carp croak),
		qw(Dumper),
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
		 year    => $year)."\n") unless @ARGV && $ARGV[0] =~ /-(P|-?printcfg)$/;
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

__END__

=head1 NAME

EB - EekBoek * Bookkeeping software for small and medium-size businesses

=head1 SYNOPSIS

EekBoek is a bookkeeping package for small and medium-size businesses.
Unlike other accounting software, EekBoek has both a command-line
interface (CLI) and a graphical user-interface (GUI). Furthermore, it
has a complete Perl API to create your own custom applications.

EekBoek is designed for the Dutch/European market and currently
available in Dutch only. An English translation is in the works (help
appreciated).

=head1 DESCRIPTION

For a description how to use the program, see L<http://www.squirrel.nl/eekboek/docs/index.html>.

=head1 BUGS AND PROBLEMS

Please use the eekboek-users mailing list at SourceForge.

=head1 AUTHOR AND CREDITS

Johan Vromans (jvromans@squirrel.nl) wrote this module.

Web site: L<http://www.squirrel.nl/eekboek>.

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2005-2006 by Squirrel Consultancy. All
rights reserved.

This program is free software; you can redistribute it and/or modify
it under the terms of either: a) the GNU General Public License as
published by the Free Software Foundation; either version 1, or (at
your option) any later version, or b) the "Artistic License" which
comes with Perl.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See either the
GNU General Public License or the Artistic License for more details.
