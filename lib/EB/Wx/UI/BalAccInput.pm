#! perl

# $Id: BalAccInput.pm,v 1.4 2008/02/04 23:25:49 jv Exp $

package EB::Wx::UI::BalAccInput;

# A wrapper around AccInput.

# Since we need to specify the selection list at creation time, we
# select the desired list based on the class name.

use base qw(EB::Wx::UI::AccInput);

1;
