#! perl

# Wxhtml.pm -- WxHtml backend for BTW Aangifte
# RCS Info        : $Id: Wxhtml.pm,v 1.2 2008/03/10 17:41:32 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Mar  6 14:20:53 2008
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar 10 18:29:56 2008
# Update Count    : 9
# Status          : Unknown, Use with caution!

package EB::Report::BTWAangifte::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

our $VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)/g;

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
	print { $self->{fh} } ("</table>\n");
	print { $self->{fh} } ("<p class=\"warning\">\n");
	print { $self->{fh} } (join("<br>\n", map { $self->html($_) } @_) );
	print { $self->{fh} } ("</p>\n");
	print { $self->{fh} } ("<table>\n");
    }
    $self->SUPER::finish;
}

1;

