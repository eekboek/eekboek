#! perl

package main;

our $state;

package EB::Wx::Report::Journaal;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me, $args) = @_;
    $self->SetDetails(1, 0, 1,
		      [ _T("Alleen totaal"),
			_T("Volledig"),
		      ]);
    $self->{pref_from_to} = 3;
    $self->SetTitle("Journaal");

    if ( $args->{select} ) {
	$self->{pref_dbk} = $args->{select};
	$self->{detail} = 1;
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
    my $output;

    delete($self->{pref_dbk}) if $self->{prefs_changed};

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

