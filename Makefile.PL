# Makefile.PL -- Build file for EekBoek
# RCS Info        : $Id: Makefile.PL,v 1.17 2008/09/09 19:16:33 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep  2 14:25:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep  9 15:23:47 2008
# Update Count    : 102
# Status          : Unknown, Use with caution!

# Ease the life of the CPAN testers.
exit 0 if $ENV{AUTOMATED_TESTING} && $] < 5.008003;

use 5.008003;

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
	      VERSION_FROM => "lib/EekBoek.pm",
	      PREREQ_PM   => { %{$data->{prereq_pm}},
			       %{$data->{buildreq_pm}},
			     },
	      PM          => filelist("lib", '$(INST_LIBDIR)/'),
	     );

# Write .spec file, Debian control, ...
ProcessTemplates($data->{distname}, $x->{VERSION});
