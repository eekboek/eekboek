#! perl

# BalAccInput.pm -- 
# Author          : Johan Vromans
# Created On      : Thu Aug 18 14:43:02 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jun 14 21:59:20 2010
# Update Count    : 102
# Status          : Unknown, Use with caution!

package EB::Wx::UI::BalAccInput;

# A wrapper around AccInput.

# Since we need to specify the selection list at creation time, we
# select the desired list based on the class name.

use base qw(EB::Wx::UI::AccInput);

1;
