#! perl

# Wxhtml.pm -- 
# Author          : Johan Vromans
# Created On      : Tue Nov  1 14:30:57 2011
# Last Modified By: Johan Vromans
# Last Modified On: Tue Nov  1 14:47:24 2011
# Update Count    : 4
# Status          : Unknown, Use with caution!
#! perl

package EB::Report::DebcrdList::Wxhtml;

use strict;
use warnings;
use base qw(EB::Report::Reporter::WxHtml);

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	deb   => {
	    code   => { link => "deb://" },
	    acct   => { link => "gbk://" },
	},
	crd   => {
	    code   => { link => "crd://" },
	    acct   => { link => "gbk://" },
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;

