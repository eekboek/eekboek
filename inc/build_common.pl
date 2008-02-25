# build_common.inc -- Build file common info -*- perl -*-
# RCS Info        : $Id: build_common.pl,v 1.15 2008/02/25 11:54:14 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Sep  1 17:28:26 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Feb  5 11:52:34 2008
# Update Count    : 57
# Status          : Unknown, Use with caution!

use strict;
use Config;
use File::Spec;

our $data;

$data =
  { %$data,
    author          => 'Johan Vromans (jvromans@squirrel.nl)',
    abstract        => 'Elementary Bookkeeping (for the Dutch/European market)',
    pl_files        => {},
    installtype     => 'site',
    modname         => 'EekBoek',
    distname        => 'EekBoek',
    license         => "perl",
    script_files    => [ map { File::Spec->catfile("script", $_) }
			 qw(ebshell) ],
    prereq_pm =>
    { 'Getopt::Long'        => '2.13',
      'Term::ReadLine'      => 0,
      $^O eq "linux" ? ('Term::ReadLine::Gnu' => 0) : (),
      'DBI'                 => '1.40',
#     'Config::IniFiles'    => '2.38',
#     'Text::CSV_XS'        => 0,
#     'Locale::gettext'     => '1.05',
      #
      # These are required for the build/test, and will be included.
      'Module::Build'	    => '0.26',
      'IPC::Run3'	    => '0.034',
    },
    recomm_pm =>
    { 'Getopt::Long'        => '2.32',
      'Archive::Zip'	    => '1.16',
      'HTML::Entities'	    => '1.35',
      'DBD::Pg'             => '1.41',
      'DBD::SQLite'         => '1.13',
    },
    usrbin => "/usr/bin",
  };

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

sub filelist {
    my ($dir, $pfx) = @_;
    $pfx ||= "";
    my $dirp = quotemeta($dir . "/");
    my $pm;

    open(my $mf, "MANIFEST") or return filelist_dyn($dir, $pfx);
    while ( <$mf> ) {
	chomp;
	next unless /$dirp(.*)/;
	$pm->{$_} = $pfx ? $pfx . $1 : $_;
    }
    close($mf);
    $pm;
}

sub filelist_dyn {
    my ($dir, $pfx) = @_;
    use File::Find;
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

sub WriteSpecfile {
    my $name    = shift;
    my $version = shift;

    my $fh;
    if ( open ($fh, "$name.spec.in") ) {
	print "Writing RPM spec file...\n";
	my $newfh;
	open ($newfh, ">$name.spec");
	while ( <$fh> ) {
	    s/%define pkgname \w+/%define pkgname $name/;
	    s/%define pkgversion [\d.]+/%define pkgversion $version/;
	    print $newfh $_;
	}
	close($newfh);
    }
}

sub vcopy($$) {
    warn("WARNING: vcopy is untested!\n");
    my ($file, $vars) = @_;

    my $pat = "(";
    foreach ( keys(%$vars) ) {
	$pat .= quotemeta($_) . "|";
    }
    chop($pat);
    $pat .= ")";

    $pat = qr/\b$pat\b/;

    warn("=> $pat\n");

    my $fin = $file . ".in";
    open(my $fi, "<$fin") or die("Cannot open $fin: $!\n");
    open(my $fo, ">$file") or die("Cannot create $file: $!\n");
    while ( <$fi> ) {
	s/$pat/$vars->{$1}/ge;
	print;
    }
    close($fo);
    close($fi);
}

1;
