# Makefile.PL -- Build file for EekBoek
# RCS Info        : $Id: Makefile.PL,v 1.2 2005/09/20 19:30:42 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep  2 14:25:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 20 21:28:45 2005
# Update Count    : 65
# Status          : Unknown, Use with caution!

use strict;

use inc::Module::Install;
#use ExtUtils::MakeMaker;

our $data = {};

require 'build_common.inc';

# Warn on non-standard install locations.
checkbin(<<EOD);
You may consider to pass INSTALLSCRIPT=$data->{usrbin} (or some other
convenient location) to "make install".
EOD

# Write Makefile.
WriteMakefile(
	      NAME       => $data->{name},
	      ($] >= 5.005) ?
	      ( AUTHOR	  => $data->{author},
		ABSTRACT  => $data->{abstract} ) : (),
	      PL_FILES    => $data->{pl_files},
	      INSTALLDIRS => $data->{installtype},
	      DISTNAME    => $data->{distname},
	      EXE_FILES   => $data->{script},
	      VERSION_FROM => "lib/EB.pm",
	      PREREQ_PM   => $data->{prereq_pm},
	      PM          => filelist("lib", '$(INST_LIBDIR)'),
	     );
