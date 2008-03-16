#! perl

package EB::Report::Open::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	tdebcrd     => {
	    _style => { colour => 'red'  },
	},
	trelatie    => {
	    _style => { colour => 'blue' },
	},
	data        => {
	    bsk => { link => "jnl://" },
        },
	cdata        => {
	    bsk => { link => "jnl://" },
	    rel => { link => "crd://" },
        },
	ddata        => {
	    bsk => { link => "jnl://" },
	    rel => { link => "deb://" },
        },
	prevdata    => {
	    bsk => { colour => 'red' },
        },
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

