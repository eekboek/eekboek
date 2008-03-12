#! perl

package EB::Report::Debcrd::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.3 $ =~ /(\d+)/g;

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	bsk   => {
	    bsknr  => { link => "jnl://" },
	},
	paid  => {
	    bsknr  => { link => "jnl://" },
	},
	h1    => {
	    _style => { colour => 'red',
			size   => '+2',
		      }
	},
	grand => {
	    _style => { colour => 'blue' }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

