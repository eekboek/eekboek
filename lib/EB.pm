#! perl --			-*- coding: utf-8 -*-

use utf8;

# EB.pm -- EekBoek Base module.
# Author          : Johan Vromans
# Created On      : Fri Sep 16 18:38:45 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Mar  3 10:25:46 2011
# Update Count    : 270
# Status          : Unknown, Use with caution!

package main;

our $app;

package EB;

use strict;
use base qw(Exporter);

use EekBoek;

our @EXPORT;
our @EXPORT_OK;

# Establish location of our run-time resources.
my $lib;
sub libfile {
    my ($f) = @_;

    unless ( $lib ) {
	# Cava.
	if ( $Cava::Packager::PACKAGED ) {
	    return Cava::Packager::GetResourcePath()."/$f";
	}
	else {
	    $lib = $INC{"EB.pm"};
	    $lib =~ s/EB\.pm$//;
	}
    }
    $lib."EB/res/$f";
}

sub findlib {
    my ($file) = @_;

    # Cava.
    if ( $Cava::Packager::PACKAGED ) {
	my $found = Cava::Packager::GetUserFile($file);
	return $found if -f $found;
	$found = Cava::Packager::GetResource($file);
	return $found if -f $found;
    }

    foreach ( @INC ) {
	return "$_/EB/usr/$file" if -e "$_/EB/usr/$file";
	return "$_/EB/res/$file" if -e "$_/EB/res/$file";
	return "$_/EB/$file" if -e "$_/EB/$file";
    }
    undef;
}

use lib ( grep { defined } findlib("CPAN") );

# Some standard modules (locale-free).
use EB::Globals;
use Carp;
use Data::Dumper;
use Carp::Assert;

BEGIN {
    # The CLI and GUI use different EB::Locale modules.
    if ( $app ) {
	require EB::Wx::Locale;	# provides EB::Locale, really
    }
    else {
	require EB::Locale;
    }
    EB::Locale::->import;
}

# Some standard modules (locale-dependent).
use EB::Utils;

# Export our and the imported globals.
@EXPORT = ( @EB::Globals::EXPORT,
	    @EB::Utils::EXPORT,
	    @EB::Locale::EXPORT,
	    qw(carp croak),		# Carp
	    qw(Dumper),			# Data::Dumper
	    qw(findlib libfile),	# <self>
	    qw(assert affirm),		# Carp::Assert
	  );

our $ident;
our $imsg;
our $url = "http://www.eekboek.nl";

unless ( $ident ) {		# already done (can this happen?)

    my $year = 2005;
    my $thisyear = (localtime(time))[5] + 1900;
    $year .= "-$thisyear" unless $year == $thisyear;
    $ident = __x("{name} {version}",
		 name    => $EekBoek::PACKAGE,
		 version => $EekBoek::VERSION);
    my @locextra;
    push(@locextra, _T("Nederlands")) if LOCALISER;
    $imsg = __x("{ident}{extra}{locale} -- Copyright {year} Squirrel Consultancy",
		ident   => $ident,
		extra   => ($app ? " Wx" : ""),
		locale  => (@locextra ? " (".join(", ", @locextra).")" : ""),
		year    => $year);
    warn($imsg, "\n") unless @ARGV && $ARGV[0] =~ /-(P|-?printconfig)$/;

    eval {
	require Win32;
	my @a = Win32::GetOSVersion();
	my ($id, $major) = @a[4,1];
	die unless defined $id;
	warn(_T("EekBoek is VRIJE software, ontwikkeld om vrij over uw eigen gegevens te kunnen beschikken.")."\n");
	warn(_T("Met uw keuze voor het Microsoft Windows besturingssysteem geeft u echter alle vrijheden weer uit handen. Dat is erg triest.")."\n");
    } unless $ENV{AUTOMATED_TESTING};

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
