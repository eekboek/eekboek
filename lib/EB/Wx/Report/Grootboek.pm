#! perl

# $Id: Grootboek.pm,v 1.5 2008/03/06 14:36:36 jv Exp $

package main;

our $state;

package EB::Wx::Report::Grootboek;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->SetTitle(_T("Grootboek"));
    $self->{pref_from_to} = 3;
    $self->SetDetails(2,0,2);
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

    require EB::Report::Grootboek;

    eval {
    EB::Report::Grootboek->new->perform
	({ generate => "wxhtml",
	   @period,
	   detail  => $self->GetDetail,
	   $self->{pref_acct} ? ("select" => $self->{pref_acct}) : (),
	   output => \$output,
	 });
    };
    if ( $@ ) {
	$output = $@;
    }

    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

1;

