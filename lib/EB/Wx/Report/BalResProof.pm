#! perl

# $Id: BalResProof.pm,v 1.5 2008/02/04 23:25:49 jv Exp $

package main;

our $state;
our $app;
our $dbh;

package EB::Wx::Report::BalResProof;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    if ( $me eq "bal" ) {
	$self->SetTitle(_T("Balans"));
	$self->{pref_from_to} = 2;
    }
    elsif ( $me eq "obal" ) {
	$self->SetTitle(_T("Openingsbalans"));
	$self->{pref_from_to} = 0;
    }
    elsif ( $me eq "prf" ) {
	$self->SetTitle(_T("Proef- en Saldibalans"));
	$self->{pref_from_to} = 2;
    }
    else {
	$self->SetTitle(_T("Resultaatrekening"));
	$self->{pref_from_to} = 3;
    }
    $self->SetDetails(2, -1, 2);
    $self->refresh;
}

sub refresh {
    my ($self) = @_;

    my @period;

    if ( defined($self->{pref_bky}) ) {
	@period = ("boekjaar", $self->{pref_bky});
    }
    elsif ( defined($self->{pref_per}->[0]) ) {
	@period = ("periode", [ @{$self->{pref_per}} ]);
    }
    elsif ( defined($self->{pref_per}->[1]) ) {
	@period = ("per", $self->{pref_per}->[1]);
    }
    else {
	@period = ("boekjaar", $self->{pref_bky} = $state->bky);
    }

    my $output;
    if ( $self->{mew} eq "rprfw" ) {
	require EB::Report::Proof;
	EB::Report::Proof->new->perform
	    ({ backend => "EB::Wx::Report::BalResProof::WxHtml",
	       @period,
	       saldi => 1,
	       output => \$output,
	       detail => $self->GetDetail });
    }
    else {
	require EB::Report::Balres;
	my $fun = $self->{mew} eq "rresw"
	  ? "result"
	  : $self->{mew} eq "robalw"
	    ? "balans"
	    : "balans";
	EB::Report::Balres->new->$fun
	    ( { backend => "EB::Wx::Report::BalResProof::WxHtml",
	       @period,
	        detail => $self->GetDetail,
		$self->{mew} eq "robalw" ? ( opening => 1 ) : (),
		output => \$output,
	      } );
    }
    $self->html->SetPage($output);
    $self->htmltext = $output;
}

################ Report handler for Balans/Report ################

package EB::Wx::Report::BalResProof::WxHtml;

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

