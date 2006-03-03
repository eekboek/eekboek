# Makefile.PL -- Build file for EekBoek
# RCS Info        : $Id: Makefile.PL,v 1.7 2006/03/03 21:14:13 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep  2 14:25:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar  3 22:00:01 2006
# Update Count    : 80
# Status          : Unknown, Use with caution!

use strict;

#use inc::Module::Install;
use ExtUtils::MakeMaker;

our $data = {};

require 'build_common.inc';

# Warn on non-standard install locations.
checkbin(<<EOD);
You may consider to pass INSTALLSCRIPT=$data->{usrbin} (or some other
convenient location) to "make install".
EOD

# Write Makefile.
my $x = 
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

# Write .spec file.
WriteSpecfile($data->{distname}, $x->{VERSION});

# Extra.
sub MY::postamble {
    my $ret = <<EOD;
ivp : pure_all
	cd ivp; sh ./verify.sh
EOD

    if ( -s "ppm/mkppd" ) {
	$ret .= <<EOD;

ppmdist : pure_all
	sh ppm/mkppd
EOD
    }	
    return $ret;
}
