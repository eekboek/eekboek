#! perl

package EB::Report::Grootboek::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	d     => {
	    bsk    => { link => "jnl://" },
	    desc   => { indent => 2      },
	},
	h1    => {
	    _style => { colour => 'red',
			size   => '+2',
		      }
	},
	h2    => {
	    _style => { colour => 'red'  },
	    desc   => { indent => 1,},
	},
	t1    => {
	    _style => { colour => 'blue',
			size   => '+1',
		      }
	},
	t2    => {
	    _style => { colour => 'blue' },
	    desc   => { indent => 1      },
	},
	tm     => {
	    _style => { colour => 'red',
			size   => '+2',
		      }
	},
	tg => {
	    _style => { colour => 'blue' }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;
