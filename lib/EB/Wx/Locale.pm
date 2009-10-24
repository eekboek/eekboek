# Locale.pm -- EB Locale setup (GUI version)
# RCS Info        : $Id: Locale.pm,v 1.2 2009/10/24 20:00:27 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Sep 16 20:27:25 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct 24 21:59:01 2009
# Update Count    : 109
# Status          : Unknown, Use with caution!

package EB::Locale;

use strict;

use constant GUIPACKAGE  => "ebgui";
use constant COREPACKAGE => "ebcore";

use base qw(Exporter);

our @EXPORT_OK = qw(LOCALISER _T __x __n __nx __xn);
our @EXPORT = @EXPORT_OK;

=begin alternative

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

=cut

sub _T($) { $_[0] }

sub LOCALISER() { "" };

# Variable expansion. See GNU gettext for details.
sub __expand($%) {
    my ($t, %args) = @_;
    my $re = join('|', map { quotemeta($_) } keys(%args));
    $t =~ s/\{($re)\}/defined($args{$1}) ? $args{$1} : "{$1}"/ge;
    $t;
}

# Translation w/ variables.
sub __x($@) {
    my ($t, %vars) = @_;
    __expand(_T($t), %vars);
}

# Translation w/ singular/plural handling.
sub __n($$$) {
    my ($sing, $plur, $n) = @_;
    _T($n == 1 ? $sing : $plur);
}

# Translation w/ singular/plural handling and variables.
sub __nx($$$@) {
    my ($sing, $plur, $n, %vars) = @_;
    __expand(__n($sing, $plur, $n), %vars);
}

# Make __xn a synonym for __nx.
*__xn = \&__nx;

# Perl magic.
#*_=\&_T;

1;
