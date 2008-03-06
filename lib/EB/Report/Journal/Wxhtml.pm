#! perl

# Wxhtml.pm -- WxHtml backend for Journal reports.
# RCS Info        : $Id: Wxhtml.pm,v 1.2 2008/03/06 14:34:41 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Feb  7 14:21:31 2008
# Last Modified By: Johan Vromans
# Last Modified On: Thu Mar  6 15:27:09 2008
# Update Count    : 3
# Status          : Unknown, Use with caution!

package EB::Report::Journal::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)/g;

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	head    => {
	    _style => { colour => 'red',
		      }
	},
	total    => {
	    _style => { colour => 'blue',
		      }
	},
	data    => {
	    desc => { indent => '+2' },
	    bsk  => { indent => '+2' },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

