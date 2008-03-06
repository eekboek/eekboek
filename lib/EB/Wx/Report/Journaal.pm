#! perl

# $Id: Journaal.pm,v 1.7 2008/03/06 14:36:36 jv Exp $

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
	({ generate => "wxhtml",
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

1;

