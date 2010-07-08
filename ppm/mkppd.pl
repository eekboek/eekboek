#!/usr/bin/perl

use strict;
use warnings;
use File::Path;
use lib qw(lib);
use EekBoek;			# for $VERSION

warn("Cleaning up blib ...\n");
rmtree(['blib/man1',
	'blib/man3',
	'blib/script',
	'blib/bindoc',
	'blib/libdoc',
	'blib/bin',
	], 1, 0);

mkpath(['blib/bin'], 1, 0777);
open(my $fh, '>', 'blib/bin/.exists')
  or die("blib/bin/.exists: $!\n");
close($fh);

warn("Preparing blib ...\n");
for ( qw(ebshell ebwxshell) ) {
    system("cp script/$_ blib/bin/$_.pl");
    system("cp ppm/$_.bat blib/bin/$_.bat");
}

warn("Construct the kit ...\n");

if ( $EekBoek::VERSION =~ /^(\d+)\.(\d+)\.(\d+)\.RC(\d+)$/ ) {
    # This is bound to fail sometime...
    my ( $maj, $min, $upd, $rc ) = ( $1, $2, $3, $4 );
    $min--, $upd += 100 if --$upd < 0;
    $maj--, $min += 100 if $min < 0;
    $EekBoek::VERSION = sprintf( "%d.%02d.%02d.%02d", $maj, $min, $upd, $rc );
}

($EekBoek::VERSION.".00") =~ /^(\d+)\.(\d+)\.(\d+)(?:\.(\d+))?/
  or die("V ".$EekBoek::VERSION.".00");

my $a = 0 + $1;
my $b = 0 + $2;
my $c = 0 + $3;
my $d = 0 + $4;

my $vv = sprintf("%d_%02d", $a, $b);
$vv .= sprintf("_%02d", $c);
$vv .= sprintf("_%02d", $d) if $d;

system("tar -zcf ../Released/ppms/PPM-EekBoek-$vv.tgz blib");

warn("Construct EekBoek.ppd ...\n");

undef $fh;
my $file = "../Released/ppms/EekBoek-$vv.ppd";
my $repo = "repo/windows";
$repo .= "-testing" if $b % 2;

open($fh, '>', $file) or die("$file: $!\n");
print { $fh } << "END_PPD";
<SOFTPKG NAME="EekBoek" VERSION="$a,$b,$c,$d">
    <TITLE>EekBoek</TITLE>
    <ABSTRACT>Elementary Bookkeeping (for the Dutch/European market)</ABSTRACT>
    <AUTHOR>Johan Vromans (jvromans\@squirrel.nl)</AUTHOR>
    <IMPLEMENTATION>
        <DEPENDENCY NAME="DBD-SQLite" VERSION="1,13,0,0" />
        <DEPENDENCY NAME="DBI" VERSION="1,4,0,0" />
        <DEPENDENCY NAME="Wx" VERSION="0,74,0,0" />
	<OS NAME="MSWin32" />
        <CODEBASE HREF="http://www.eekboek.nl/$repo/PPM-EekBoek-$vv.tgz" />
    </IMPLEMENTATION>
</SOFTPKG>
END_PPD

# Latest.
my $latest = "../Released/ppms/EekBoek"
  . ($b % 2 ? "-testing" : "")
  . ".ppd";

unlink($latest);
system("cp $file $latest");

