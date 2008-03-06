#! perl

# $Id: DebCrd.pm,v 1.5 2008/03/06 14:36:36 jv Exp $

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
	 { generate => "wxhtml",
	   @period,
	   $self->{pref_open} ? ("openstaand" => 1) : (),
	   output   => \$output,
	 });
    };
    if ( $@ ) {
	$output = $@;
    }

    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

1;

