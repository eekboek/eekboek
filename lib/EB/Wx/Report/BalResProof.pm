#! perl

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
    $self->SetDetails(2, -1, 2,
		     [ _T("Op hoofdverdichting"),	#  0
		       _T("Op verdichting"),		#  1
		       _T("Gedetailleerd"),		#  2
		       _T("Op grootboekrekening"),	# -1
		     ]);
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
	    ({ generate => "wxhtml",
	       @period,
	       saldi    => 1,
	       output   => \$output,
	       detail   => $self->GetDetail });
    }
    else {
	require EB::Report::Balres;
	my $fun = $self->{mew} eq "rresw"
	  ? "result"
	  : $self->{mew} eq "robalw"
	    ? "balans"
	    : "balans";
	EB::Report::Balres->new->$fun
	    ( { generate => "wxhtml",
	       @period,
	        detail   => $self->GetDetail,
		$self->{mew} eq "robalw" ? ( opening => 1 ) : (),
		output   => \$output,
	      } );
    }
    $self->html->SetPage($output);
    $self->htmltext = $output;
}

1;
