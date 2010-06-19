#! perl

package main;

our $state;

package EB::Wx::Report::DebCrd;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me, $args) = @_;
    $self->{pref_from_to} = 3;
    $self->SetTitle($me eq "deb" ? "Debiteurenoverzicht" : "Crediteurenoverzicht");
    $self->SetDetails(0,0,0);
    if ( $args->{select} ) {
	$self->{pref_rel} = [ $args->{select} ];
    }
    if ( $args->{periode} ) {
	my $p = parse_date_range($args->{periode});
	delete($self->{pref_bky});
	$self->{pref_per} = $p;
    }

    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    my $output = "";

    delete($self->{pref_rel}) if $self->{prefs_changed};

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
	($self->{pref_rel},
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

