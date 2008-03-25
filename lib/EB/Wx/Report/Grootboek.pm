#! perl

# $Id: Grootboek.pm,v 1.6 2008/03/25 22:32:19 jv Exp $

package main;

our $state;

package EB::Wx::Report::Grootboek;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me, $args) = @_;
    $self->SetTitle(_T("Grootboek"));
    $self->{pref_from_to} = 3;
    $self->SetDetails(2,0,2);

    if ( $args->{select} ) {
	$self->{pref_acct} = $args->{select};
	$self->{detail} = 2;
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

    delete($self->{pref_acct}) if $self->{prefs_changed};

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

