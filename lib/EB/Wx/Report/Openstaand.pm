#! perl

# $Id: Openstaand.pm,v 1.3 2008/03/25 22:33:06 jv Exp $

package main;

our $state;

package EB::Wx::Report::Openstaand;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->{pref_from_to} = 2;
    $self->SetTitle("Openstaande posten");
    $self->SetDetails(0,0,0);
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

    require EB::Report::Open;
    my $output;
    EB::Report::Open->new->perform
	({ generate => 'wxhtml',
	   @period,
	   output   => \$output,
	 });
    $self->{w_report}->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

1;

