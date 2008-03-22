#! perl

# EB.pm -- EekBoek Base module.
# RCS Info        : $Id: EB.pm,v 1.86 2008/03/22 15:54:57 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep 16 18:38:45 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Mar 22 16:45:55 2008
# Update Count    : 219
# Status          : Unknown, Use with caution!

package main;

our $app;
our $cfg;

package EB;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.86 $ =~ /(\d+)/g;

use strict;
use base qw(Exporter);

use EekBoek;

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
use EB::Assert;
use Data::Dumper;

BEGIN {
    # The core and GUI use a different EB::Locale module.
    if ( $app ) {
	require EB::Wx::Locale;
	# Force UNICODE for Wx.
	$cfg->newval(qw(locale unicode), 1);
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
		qw(findlib),
		qw(assert affirm),
	      );
}

our @months;
our @month_names;
our @days;
our @day_names;
our $ident;
our $imsg;
our $url = "http://www.eekboek.nl";

# Most elegant (and correct) would be to use an INIT block here, but
# currently PAR is not able to handle INIT blocks.
INIT {
    return if $ident;		# already done
    my $incompatibleOS = 0;

    my $year = 2005;
    my $thisyear = (localtime(time))[5] + 1900;
    $year .= "-$thisyear" unless $year == $thisyear;
    $ident = __x("{name} {version}",
		 name    => $EekBoek::PACKAGE,
		 version => $EekBoek::VERSION);
    my @locextra;
    push(@locextra, _T("Nederlands")) if LOCALISER;
    push(@locextra, "Latin1") unless $cfg->val(qw(locale unicode), 0);
    $imsg = __x("{ident}{extra}{locale} -- Copyright {year} Squirrel Consultancy",
		ident   => $ident,
		extra   => ($app ? " Wx " : ""),
		locale  => (@locextra ? " (".join(", ", @locextra).")" : ""),
		year    => $year);
    warn($imsg, "\n") unless @ARGV && $ARGV[0] =~ /-(P|-?printcfg)$/;

    eval {
	require Win32;
	my @a = Win32::GetOSVersion();
	my ($id, $major) = @a[4,1];
	die unless defined $id;
	warn(_T("EekBoek is VRIJE software, ontwikkeld om vrij over uw eigen gegevens te kunnen beschikken.")."\n");
	if ( $id <= 1 || ( $id == 2 && $major <= 5) || $id >= 3 ) {
	    warn(_T("Met uw keuze voor het Microsoft Windows besturingssysteem geeft u echter alle vrijheden weer uit handen. Dat is erg triest.")."\n");
	}
	else {
	    $incompatibleOS++;
	    warn(_T("Dit is niet te verenigen met uw keuze voor dit Microsoft Windows besturingssysteem.")."\n");
	}
    } unless $ENV{AUTOMATED_TESTING};

    @months =
      split(" ", _T("Jan Feb Mrt Apr Mei Jun Jul Aug Sep Okt Nov Dec"));
    @month_names =
      split(" ", _T("Januari Februari Maart April Mei Juni Juli Augustus September Oktober November December"));
    @days =
      split(" ", _T("Zon Maa Din Woe Don Vri Zat"));
    @day_names =
      split(" ", _T("Zondag Maandag Dinsdag Woensdag Donderdag Vrijdag Zaterdag"));
    die("?"._T("FATALE FOUT: Ongeschikt besturingssysteem")."\n") if $incompatibleOS;
}

sub findlib {
    my ($file) = @_;
    foreach ( @INC ) {
	return "$_/EB/$file" if -e "$_/EB/$file";
    }
    undef;
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

For a description how to use the program, see L<http://www.eekboek.nl/docs/index.html>.

=head1 BUGS AND PROBLEMS

Please use the eekboek-users mailing list at SourceForge.

=head1 AUTHOR AND CREDITS

Johan Vromans (jvromans@squirrel.nl) wrote this module.

Web site: L<http://www.eekboek.nl>.

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2005-2008 by Squirrel Consultancy. All
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
