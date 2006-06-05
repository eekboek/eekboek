# Import.pm -- Import EekBoek administratie
# RCS Info        : $Id: Import.pm,v 1.5 2006/06/05 19:37:13 jv Exp $
# Author          : Johan Vromans
# Created On      : Tue Feb  7 11:56:50 2006
# Last Modified By: Johan Vromans
# Last Modified On: Fri Jun  2 15:57:40 2006
# Update Count    : 23
# Status          : Unknown, Use with caution!

package main;

our $dbh;

package EB::Import;

use strict;
use warnings;

use EB;
use EB::Format;			# needs to be setup before we can use Schema

my $ident;

sub do_import {
    my ($self, $cmdobj, $opts) = @_;

    require EB::Tools::Schema;

    my $dir = $opts->{dir};
    if ( $dir ) {
	die("?".__x("Directory {dir} bestaat niet",
		    dir => $dir)."\n") unless -d $dir;
	die("?".__x("Geen toegang tot directory {dir}",
		    dir => $dir)."\n") unless -r _ || -x _;

	-r "$dir/schema.dat"
	  or die("?".__x("Bestand \"{file}\" ontbreekt ({err})",
			 file => "schema.dat", err => $!)."\n");
	open(my $relaties, "<", "$dir/relaties.eb")
	  or die("?".__x("Bestand \"{file}\" ontbreekt ({err})",
			 file => "relaties.eb", err => $!)."\n");
	open(my $opening, "<", "$dir/opening.eb")
	  or die("?".__x("Bestand \"{file}\" ontbreekt ({err})",
			 file => "opening.eb", err => $!)."\n");
	open(my $mutaties, "<", "$dir/mutaties.eb")
	  or die("?".__x("Bestand \"{file}\" ontbreekt ({err})",
			 file => "mutaties.eb", err => $!)."\n");

	# Create DB.
	$dbh->cleardb if $opts->{clean};

	# Schema.
	EB::Tools::Schema->create("$dir/schema.dat");
	$cmdobj->_plug_cmds;

	# Relaties, Opening, Mutaties.
	$cmdobj->attach_file($mutaties);
	$cmdobj->attach_file($opening);
	$cmdobj->attach_file($relaties);
    }
    else {
	die("?"._T("Import van bestand is nog niet geïmplementeerd")."\n");
    }
}

1;
