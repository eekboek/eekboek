#! perl

# $Id: Openstaand.pm,v 1.1 2008/02/04 23:11:36 jv Exp $

package main;

our $state;

package EB::Wx::Report::Openstaand;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->SetDetails(0,0,0);
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    my $output = "<h1>Output</h1>";
    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

################ Report handler for Openstaand ################

package EB::Wx::Report::Openstaand::WxHtml;

use base qw(EB::Report::Reporter::WxHtml);

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

