# Build.PL -- Buildfile for EekBoek	-*-perl-*-
# Author          : Johan Vromans
# Created On      : Thu Sep  1 17:28:26 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar 29 17:26:53 2010
# Update Count    : 133
# Status          : Experimental

# Ease the life of the CPAN testers.
exit 0 if $ENV{AUTOMATED_TESTING} && $] < 5.008003;

use 5.008003;
use strict;
use lib 'inc';
use Module::Build 0.32;
use File::Find;

our $data = {};
require "inc/build_common.pl";

# Warn on non-standard install locations.
checkbin(<<EOD);
Please consult section "How Installation Paths are Determined"
of the Module::Build documentation section if you want to change
this location.
EOD

# checkexec("psql");

my $class = Module::Build->subclass(code => <<'EOF');
sub ACTION_test {
    my $self = shift;
    if ( $self->args("skipdbtests") ) {
	warn("WARNING: Skipping database tests\n");
	$ENV{EB_SKIPDBTESTS} = 1;
    }
    require Cwd;
    my $cwd = Cwd::getcwd();
    require lib;
    lib->import( "$cwd/lib/EB/CPAN", "$cwd/inc" );
    $self->SUPER::ACTION_test;
}
EOF

my $build = $class->new
  (
   module_name	       => $data->{distname},
   dist_name	       => $data->{distname},
   dist_author	       => $data->{author},
   dist_abstract       => $data->{abstract},
   license	       => $data->{license},
   requires	       => $data->{prereq_pm},
   build_requires      => $data->{buildreq_pm},
   recommends	       => $data->{recomm_pm},
   script_files	       => $data->{script_files},
   pm_files	       => filelist("lib"),
   PL_files	       => $data->{PL_files},
   get_options	       => { skipdbtests => { } },
   add_to_cleanup      =>
     [ 'pod2htm*',
       map { +"t/ivp/*.$_" } qw(sql log txt html csv)
     ],
   meta_merge	       =>
     { resources =>
	{ homepage    => 'http://www.eekboek.nl',
	  MailingList => 'http://lists.sourceforge.net/lists/listinfo/eekboek',
	}
     },
   meta_add            => {
     no_index          => { directory => [ qw(inc lib) ] },
     provides	       => {
       'EekBoek' =>
	  { file => "lib/EekBoek.pm",
	    version => "1.04.00_01",
	  },
     },
   },
  );

# Rerun to get the version right for provides => EekBoek.
$build = $class->new
  (
   module_name	       => $data->{distname},
   dist_name	       => $data->{distname},
   dist_author	       => $data->{author},
   dist_abstract       => $data->{abstract},
   license	       => $data->{license},
   requires	       => $data->{prereq_pm},
   build_requires      => $data->{buildreq_pm},
   recommends	       => $data->{recomm_pm},
   script_files	       => $data->{script_files},
   pm_files	       => filelist("lib"),
   PL_files	       => $data->{PL_files},
   get_options	       => { skipdbtests => { } },
   add_to_cleanup      =>
     [ 'pod2htm*',
       map { +"t/ivp/*.$_" } qw(sql log txt html csv)
     ],
   meta_merge	       =>
     { resources =>
	{ homepage    => 'http://www.eekboek.nl',
	  MailingList => 'http://lists.sourceforge.net/lists/listinfo/eekboek',
	}
     },
   meta_add            => {
     no_index          => { directory => [ qw(inc lib) ] },
     provides	       => {
       'EekBoek' =>
	  { file => "lib/EekBoek.pm",
	    version => $build->dist_version,
	  },
     },
   },
  );

$build->create_build_script;

if ( $build->os_type eq "Unix" ) {
    # Write .spec file, Debian control, ...
    ProcessTemplates($build->dist_name, $build->dist_version);
}

# Debian needs this.
1;
