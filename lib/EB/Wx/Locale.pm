#! perl

# Locale.pm -- EB Locale setup (GUI version)
# Author          : Johan Vromans
# Created On      : Fri Sep 16 20:27:25 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Mar  3 13:39:35 2011
# Update Count    : 120
# Status          : Unknown, Use with caution!

package EB::Locale;

# IMPORTANT:
#
# This module is used (require-d) by module EB only.
# No other modules should try to play localisation tricks.
#
# Note: Only _T must be defined. The rest is defined in EB::Utils.

use strict;

use constant GUIPACKAGE  => "ebwxshell";
use constant COREPACKAGE => "ebcore";

use base qw(Exporter);

our @EXPORT_OK = qw(_T);
our @EXPORT = @EXPORT_OK;

use Wx qw(wxLANGUAGE_DEFAULT wxLOCALE_LOAD_DEFAULT);
use Wx::Locale gettext => '_T';

our $gui_localiser;

unless ( $gui_localiser ) {
    $gui_localiser = Wx::Locale->new(wxLANGUAGE_DEFAULT,
				     wxLOCALE_LOAD_DEFAULT);
    # Since EB is use-ing Locale, we cannot use the EB exported libfile yet.
    $gui_localiser->AddCatalogLookupPathPrefix(EB::libfile("locale"));
    $gui_localiser->AddCatalog(GUIPACKAGE);
    $gui_localiser->AddCatalog(COREPACKAGE);
}

sub LOCALISER() { "Wx::Locale" }

1;
