#! perl

# Wxhtml.pm -- WxHtml backend for Balans/Result reports
# RCS Info        : $Id: Wxhtml.pm,v 1.1 2008/02/07 13:21:20 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Feb  7 14:20:53 2008
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  7 14:21:15 2008
# Update Count    : 1
# Status          : Unknown, Use with caution!

package EB::Report::Balres::Wxhtml;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.1 $ =~ /(\d+)/g;

use EB;
use base qw(EB::Report::Reporter::WxHtml);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    return $self;
}

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

