#! perl

# $Id: Journaal.pm,v 1.6 2008/02/11 15:10:29 jv Exp $

package main;

our $state;

package EB::Wx::Report::Journaal;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->SetDetails(1,0,1);
    $self->{pref_from_to} = 3;
    $self->SetTitle("Journaal");
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    my $output;

    my @period;

    if ( defined($self->{pref_bky}) ) {
	@period = ("boekjaar", $self->{pref_bky});
    }
    elsif ( defined($self->{pref_per}->[0]) ) {
	@period = ("periode", [ @{$self->{pref_per}} ]);
    }
    else {
	@period = ("boekjaar", $self->{pref_bky} = $state->bky);
    }

    require EB::Report::Journal;
    eval {
    EB::Report::Journal->new->journal
	({ backend => "EB::Wx::Report::Journaal::WxHtml",
	   @period,
	   $self->{pref_dbk} ? (select => $self->{pref_dbk}) : (),
	   output => \$output,
	   detail => $self->{detail} });
    };
    if ( $@ ) {
	$output = $@;
    }
    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

################ Report handler for Journaal ################

package EB::Wx::Report::Journaal::WxHtml;

use base qw(EB::Report::Reporter::WxHtml);

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

