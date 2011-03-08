#! perl

# Locale.pm -- EB Locale setup (core version)
# Author          : Johan Vromans
# Created On      : Fri Sep 16 20:27:25 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Mar  8 20:15:28 2011
# Update Count    : 144
# Status          : Unknown, Use with caution!

package EB::Locale;

# IMPORTANT:
#
# This module is used (require-d) by module EB only.
# No other modules should try to play localisation tricks.
#
# Note: Only _T must be defined. The rest is defined in EB::Utils.

use strict;

use constant COREPACKAGE => "ebcore";

use base qw(Exporter);

our @EXPORT_OK = qw(_T);
our @EXPORT = @EXPORT_OK;

# This module supports three different gettext implementations.

use POSIX qw(setlocale LC_MESSAGES);

my $core_localiser;
our $LOCALISER;			# for outside checking

eval {
    require Locale::gettext;
    # Use outer settings.
    setlocale(LC_MESSAGES);

    unless ( $core_localiser ) {
	$core_localiser = Locale::gettext->domain(COREPACKAGE);
	# Since EB is use-ing Locale, we cannot use the EB exported libfile yet.
	$core_localiser->dir(EB::libfile("locale"));

	eval 'sub _T { $core_localiser->get($_[0]) }';
	$LOCALISER = "Locale::gettext";
    }
};

unless ( $core_localiser ) {
    $core_localiser = "<dummy>";
    eval 'sub _T { $_[0] };';
    $LOCALISER = "";
}

sub get_language {
    $ENV{LANG};
}

sub set_language {
    # Set/change language.
    setlocale( LC_MESSAGES, $ENV{LANG} = $_[1] );
}

1;
