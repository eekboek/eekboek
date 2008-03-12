#! perl

# Wxhtml.pm -- WxHtml backend for Journal reports.
# RCS Info        : $Id: Wxhtml.pm,v 1.3 2008/03/12 14:38:29 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Feb  7 14:21:31 2008
# Last Modified By: Johan Vromans
# Last Modified On: Wed Mar 12 15:05:31 2008
# Update Count    : 8
# Status          : Unknown, Use with caution!

package EB::Report::Journal::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.3 $ =~ /(\d+)/g;

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	head    => {
	    _style => { colour => 'red'  },
	},
	chead    => {
	    _style => { colour => 'red'  },
	    rel    => { link => "crd://" },
	},
	dhead    => {
	    _style => { colour => 'red'  },
	    rel    => { link => "deb://" },
	},
	total    => {
	    _style => { colour => 'blue',
		      }
	},
	data    => {
	    desc => { indent => '+2' },
	    acct => { link => "gbk://" },
	    bsk  => { indent => '+2' },
	},
	cdata    => {
	    desc => { indent => '+2' },
	    acct => { link => "gbk://" },
	    bsk  => { indent => '+2' },
	    rel  => { link => "crd://" },
	},
	ddata    => {
	    desc => { indent => '+2' },
	    acct => { link => "gbk://" },
	    bsk  => { indent => '+2' },
	    rel  => { link => "deb://" },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

