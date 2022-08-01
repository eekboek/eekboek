#! perl

# ebwxshell -- Main script for EekBoek GUI shell
# Author          : Johan Vromans
# Created On      : Fri Dec 18 21:54:24 2009
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug  1 21:26:48 2022
# Update Count    : 136
# Status          : Unknown, Use with caution!

package main;

use strict;
use warnings;
use utf8;

# use lib qw(EekBoekLibrary);

use File::Spec;
use File::Basename;

use Wx qw[
	  wxDefaultPosition
	  wxICON_ERROR
	  wxICON_EXCLAMATION
	  wxICON_INFORMATION
	  wxOK
       ];
# If we get here, we have Wx :)

use FindBin;
our $bin = $FindBin::Bin;

# Common case when run from unpacked dist.
my $lib = File::Spec->catfile( dirname($bin), "lib" );
if ( -s File::Spec->catfile( $lib, "EekBoek.pm" ) ) {
    # Need abs paths since we're going to chdir later.
    unshift( @INC, File::Spec->rel2abs($lib) );
    my $sep = $ENV{PATH} =~ m?;??q:;::q;:;;;; # just for fun
    $ENV{PATH} = File::Spec->rel2abs($lib) . $sep . $ENV{PATH};
}

require App::Packager; App::Packager->import( qw( :name EekBoek ) );

check_install( "EekBoek", "EekBoek.pm", "EB.pm", "EB/res/schema/eekboek.sql" );

require EekBoek;
check_version( "EekBoek", $EekBoek::VERSION, "2.051" );

check_install( "De EekBoek WxShell", "EB/Wx/Shell/Main.pm", "EB/Wx/IniWiz.pm" );

# Some more version checking. Wx 0.74 is somewhat arbitrary.
check_version( "Wx", $Wx::VERSION, "0.74" );

# Versions 0.95 and 0.96 have issues with wxHTML rendering.
# Workaround courtesy of Mark Dootson.
if ( ( $Wx::VERSION =~ /^0[.,]9[56]$/ )
     &&
     ( not exists($ENV{PAR_0}) )
     &&
     !$App::Packager::PACKAGED
   ) {
    no warnings;
    *Wx::load_dll = sub {
	use warnings;
	return if $^O =~ /^darwin/i;
	Wx::_load_dll( @_ );
    };
}

# We currently support wxWidgets 2.8 and 2.9.
check_version( "wxWidgets", $Wx::wxVERSION, "2.008" );

require EB::Wx::Shell::Main;
exit if @ARGV == 1 && $ARGV[0] eq "--quit";
if ( @ARGV == 1 && $ARGV[0] eq "--version" ) {
    my $year = 2005;
    my $thisyear = (localtime(time))[5] + 1900;
    $year .= "-$thisyear" unless $year == $thisyear;
    warn( $EekBoek::PACKAGE, " ", $EekBoek::VERSION. " Wx -- ",
	  "Copyright {year} Squirrel Consultancy\n");
    exit;
    warn( $EekBoek::PACKAGE );
}

EB::Wx::Shell::Main->run;

################ Subroutines ################

sub findfile {
    my ( $file ) = @_;
    return if $App::Packager::PACKAGED;

    foreach ( @INC ) {
	my $f = File::Spec->catfile( $_, $file );
	return $f if -s $f;
    }
    return;
}

sub check_install {
    # Trust packager.
    return 1 if $App::Packager::PACKAGED;

    my ( $what, @checks ) = @_;
    foreach ( @checks ) {
	next if findfile( $_ );
	error( <<END_MSG, "Installatiefout" );
$what is niet geïnstalleerd, of kon niet worden gevonden.

Raadplaag uw systeembeheerder.
END_MSG
	return;
    }
}

sub check_version {
    my ( $what, $version, $required ) = @_;
    $version =~ s/,/./g;
    $version =~ s/^(\d+\.\d+\.\d+).*/$1/;
    return if $version ge $required;
    error( <<END_MSG, "Ontoereikende $what versie" );
De geïnstalleerde versie van $what is niet toereikend.
Versie $version is geïnstalleerd terwijl versie $required of later
is vereist.

Raadplaag uw systeembeheerder.
END_MSG
}

################ Messengers ################

sub _msg {
    my ( $msg, $caption, $style ) = @_;
    $style |= wxOK;
    my $d = Wx::MessageDialog->new ( undef,
				     $msg,
				     $caption,
				     $style, wxDefaultPosition );
    $d->ShowModal;
    $d->Destroy;
}

sub info {
    push( @_, wxICON_INFORMATION );
    goto &_msg;
}

sub error {
    push( @_, wxICON_ERROR );
    &_msg;
    exit(1);
}

sub warning {
    push( @_, wxICON_EXCLAMATION );
    goto &_msg;
}

1;

=head1 NAME

EekBoek - Bookkeeping software for small and medium-size businesses

=head1 SYNOPSIS

The graphical EekBoek shell:

  ebwxshell

The standalone documentation browser:

  ebwxshell --showhelp

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

Johan Vromans (jvromans@squirrel.nl) wrote this package.

Web site: L<http://www.eekboek.nl>.

=head1 COPYRIGHT AND DISCLAIMER

This program is Copyright 2005-2017 by Squirrel Consultancy. All
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

=cut
