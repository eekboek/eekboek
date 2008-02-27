# Build.PL -- Buildfile for EekBoek	-*-perl-*-
# Author          : Johan Vromans
# Created On      : Thu Sep  1 17:28:26 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Feb 27 10:07:39 2008
# Update Count    : 94
# Status          : Experimental

use 5.008;
use strict;
use lib 'inc';
use Module::Build 0.27_09;
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
   recommends	       => $data->{recomm_pm},
   script_files	       => $data->{script_files},
   pm_files	       => filelist("lib"),
   get_options	       => { skipdbtests => { } },
   add_to_cleanup      => [ 'pod2htm*',
			    map { +"t/ivp/*.$_" }
				qw(sql log txt html csv)
			  ],
   meta_merge	       =>
     { resources =>
	{
	   homepage => 'http://www.eekboek.nl',
	   MailingList => 'http://lists.sourceforge.net/lists/listinfo/eekboek',
	 }
     },
   meta_add            => {
     no_index          => { directory => [ qw(inc) ] },
   },
  );

$build->create_build_script;

if ( $build->os_type eq "Unix" ) {
    WriteSpecfile($build->dist_name, $build->dist_version);
}
