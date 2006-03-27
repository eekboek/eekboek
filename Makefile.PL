# Makefile.PL -- Build file for EekBoek
# RCS Info        : $Id: Makefile.PL,v 1.9 2006/03/27 12:24:05 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep  2 14:25:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar 27 11:35:33 2006
# Update Count    : 87
# Status          : Unknown, Use with caution!

use strict;

#use inc::Module::Install;
use ExtUtils::MakeMaker;

our $data = {};

require 'inc/build_common.pl';

# Warn on non-standard install locations.
checkbin(<<EOD);
You may consider to pass INSTALLSCRIPT=$data->{usrbin} (or some other
convenient location) to "make install".
EOD

# Write Makefile.
my $x =
WriteMakefile(
	      NAME       => $data->{distname},
	      ($] >= 5.005) ?
	      ( AUTHOR	  => $data->{author},
		ABSTRACT  => $data->{abstract} ) : (),
	      PL_FILES    => $data->{pl_files},
	      INSTALLDIRS => $data->{installtype},
	      DISTNAME    => $data->{distname},
	      EXE_FILES   => $data->{script_files},
	      VERSION_FROM => "lib/EB.pm",
	      PREREQ_PM   => $data->{prereq_pm},
	      PM          => filelist("lib", '$(INST_LIBDIR)'),
	     );

# Write .spec file.
WriteSpecfile($data->{distname}, $x->{VERSION});
