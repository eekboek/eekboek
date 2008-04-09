#! perl

# Wxhtml.pm -- WxHtml backend for BTW Aangifte
# RCS Info        : $Id: Wxhtml.pm,v 1.3 2008/04/09 21:02:22 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Mar  6 14:20:53 2008
# Last Modified By: Johan Vromans
# Last Modified On: Fri Mar 28 17:50:41 2008
# Update Count    : 11
# Status          : Unknown, Use with caution!

package EB::Report::BTWAangifte::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.3 $ =~ /(\d+)/g;

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

sub finish {
    my $self = shift;
    if ( @_ ) {
	$self->_print("</table>\n");
	$self->_print("<p class=\"warning\">\n");
	$self->_print(join("<br>\n", map { $self->html($_) } @_) );
	$self->_print("</p>\n");
	$self->_print("<table>\n");
    }
    $self->SUPER::finish;
}

1;

