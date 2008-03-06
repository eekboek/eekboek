#! perl

# Wxhtml.pm -- WxHtml backend for BTW Aangifte
# RCS Info        : $Id: Wxhtml.pm,v 1.1 2008/03/06 14:34:41 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Mar  6 14:20:53 2008
# Last Modified By: Johan Vromans
# Last Modified On: Thu Mar  6 15:15:46 2008
# Update Count    : 8
# Status          : Unknown, Use with caution!

package EB::Report::BTWAangifte::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	h1    => {
	    _style => { weight => 'bold', size   => '+2',},
	    num    => { colspan => 2 },
	},
	h2    => {
	    _style => { weight => 'bold' },
	    num    => { colspan => 2 },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

