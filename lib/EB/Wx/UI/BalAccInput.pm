#! perl

# BalAccInput.pm -- 
# Author          : Johan Vromans
# Created On      : Mon Jun 14 21:58:49 2010
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jun 14 21:58:59 2010
# Update Count    : 1
# Status          : Unknown, Use with caution!

package EB::Wx::UI::BalAccInput;

# A wrapper around AccInput.

# Since we need to specify the selection list at creation time, we
# select the desired list based on the class name.

use base qw(EB::Wx::UI::AccInput);

1;
