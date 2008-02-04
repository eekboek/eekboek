#! perl

# $Id: DebCrd.pm,v 1.4 2008/02/04 23:25:49 jv Exp $

package main;

our $state;

package EB::Wx::Report::DebCrd;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->{pref_from_to} = 3;
    $self->SetTitle($me eq "deb" ? "Debiteurenoverzicht" : "Crediteurenoverzicht");
    $self->SetDetails(0,0,0);
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    my $output = "";

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

    require EB::Report::Debcrd;
    my $fun = $self->{mew} eq "rdebw" ? "debiteuren" : "crediteuren";

    eval {
    EB::Report::Debcrd->new->$fun
	(undef,
	 { backend => "EB::Wx::Report::DebCrd::WxHtml",
	   @period,
	   $self->{pref_open} ? ("openstaand" => 1) : (),
	   output => \$output,
	 });
    };
    if ( $@ ) {
	$output = $@;
    }

    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

################ Report handler for Debiteuren/Crediteuren ################

package EB::Wx::Report::DebCrd::WxHtml;

use EB;
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

