# Import.pm -- Import EekBoek administratie
# RCS Info        : $Id: Import.pm,v 1.1 2006/02/07 11:45:43 jv Exp $
# Author          : Johan Vromans
# Created On      : Tue Feb  7 11:56:50 2006
# Last Modified By: Johan Vromans
# Last Modified On: Tue Feb  7 12:28:29 2006
# Update Count    : 15
# Status          : Unknown, Use with caution!

package main;

our $dbh;

package EB::Import;

use strict;
use warnings;

use EB;
use EB::Finance;

my $ident;

sub do_import {
    my ($self, $cmdobj, $opts) = @_;

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
	$dbh->cleardb;
	# Schema.
	EB::Tools::Schema->create("$dir/schema.dat");
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
