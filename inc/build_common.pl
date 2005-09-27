# build_common.inc -- Build file common info -*- perl -*-
# RCS Info        : $Id: build_common.pl,v 1.3 2005/09/27 08:30:52 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Sep  1 17:28:26 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 27 10:30:43 2005
# Update Count    : 12
# Status          : Unknown, Use with caution!

use strict;
use Config;
use File::Spec;

our $data;

$data->{author} = 'Johan Vromans (jvromans@squirrel.nl)';
$data->{abstract} = 'Elementary Bookkeeping (for the Dutch/European market)';
$data->{pl_files} = {};
$data->{installtype} = 'site';
$data->{distname} = 'EekBoek';
$data->{name} = "eekboek";
$data->{script} = [ map { File::Spec->catfile("script", $_) }
		     qw(ebshell) ];
$data->{prereq_pm} = {
		      'Getopt::Long' => '2.13',
		      'Term::ReadLine' => 0,
		      'Term::ReadLine::Gnu' => 0,
		      'DBI' => 1.40,
		      'DBD::Pg' => 1.41,
#		      'Text::CSV_XS' => 0,
#		      'Locale::gettext' => 1.05,
	       };
$data->{recomm_pm} = {
		'Getopt::Long' => '2.32',
	       };
$data->{usrbin} = "/usr/bin";

sub checkbin {
    my ($msg) = @_;
    my $installscript = $Config{installscript};

    return if $installscript eq $data->{usrbin};
    print STDERR <<EOD;

WARNING: This build process will install a user accessible script.
The default location for user accessible scripts is
$installscript.
EOD
    print STDERR ($msg);
}

use File::Find;

sub filelist {
    my ($dir, $pfx) = @_;
    $pfx ||= "";
    my $dirl = length($dir);
    my $pm;
    find(sub {
	     if ( $_ eq "CVS" ) {
		 $File::Find::prune = 1;
		 return;
	     }
	     return if /^#.*#/;
	     return if /~$/;
	     return unless -f $_;
	     if ( $pfx ) {
		 $pm->{$File::Find::name} = $pfx .
		   substr($File::Find::name, $dirl);
	     }
	     else {
		 $pm->{$File::Find::name} = $pfx . $File::Find::name;
	     }
	 }, $dir);
    $pm;
}

1;
