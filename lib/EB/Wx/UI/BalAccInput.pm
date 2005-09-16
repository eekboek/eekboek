# $Id: BalAccInput.pm,v 1.2 2005/09/16 20:31:43 jv Exp $

package BalAccInput;

# A wrapper around AccInput.

# Since we need to specify the selection list at creation time, we
# select the desired list based on the class name.

use base qw(AccInput);

1;
