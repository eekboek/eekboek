#! perl

# Wxhtml.pm -- WxHtml backend for Balans/Result reports
# RCS Info        : $Id: Wxhtml.pm,v 1.2 2008/03/06 14:34:41 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Feb  7 14:20:53 2008
# Last Modified By: Johan Vromans
# Last Modified On: Thu Mar  6 15:18:30 2008
# Update Count    : 2
# Status          : Unknown, Use with caution!

package EB::Report::Balres::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)/g;

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	d2    => {
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
	v     => {
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

