#! perl

# $Id: BTWAangifte.pm,v 1.10 2008/03/25 22:30:49 jv Exp $

package main;

our $state;
our $dbh;

package EB::Wx::Report::BTWAangifte;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;
use Wx qw(wxICON_ERROR wxOK);

sub init {
    my ($self) = @_;
    $self->SetTitle(_T("BTW  aangifte"));
    $self->SetDetails(0,0,0);
    $self->{year} = substr($dbh->adm("begin"), 0, 4);
    $self->{btwp} = $dbh->adm("btwperiod");

    $self->{compat_periode} =
      $self->{btwp} == 1 ? "j" :
	$self->{btwp} == 4 ? "k1" :
	  $self->{btwp} == 12 ? $EB::month_names[0] : $self->{btwp};

    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    require EB::Report::BTWAangifte;

    if ( $self->{pref_periode} ) {
	$self->set_periode($self->{pref_periode});
    }

    my $output;
    my $save = $self->htmltext;
    my @msgs;
    local $SIG{__WARN__} = sub { push(@msgs, "@_") };
    eval {

    EB::Report::BTWAangifte->new->perform
	({ generate => 'wxhtml',
	   compat_periode => $self->{compat_periode},
	   output   => \$output,
	   detail   => $self->{detail} });

    $output =~ s/<table border="1" width="100%">/<table>/;
    };

    if ( $@ ) {
	my $msg = $@;
	$msg =~ s/^\?+//;
	EB::Wx::MessageDialog($self, $msg, "Fout", wxICON_ERROR|wxOK);
	$output = $save;
    }
    elsif ( @msgs ) {
	# Splice in any messages.
	my $msg = join("<br>", map { s/^\!//; $_ } @msgs);
	$output =~ s/\&nbsp;/<font color=\"red\">$msg<\/font><br>\&nbsp;/;
    }
    $self->{w_report}->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

sub set_periode {
   my ($self, $p) = @_;
   if ( $p eq "j" ) {
       $self->{compat_periode} = $p;
   }
   elsif ( $p =~ /^k(\d+)$/ ) {
       $self->{compat_periode} = $p;
   }
   elsif ( $p =~ /^m(\d+)$/ ) {
       $self->{compat_periode} = $EB::month_names[$1-1];
   }
}

1;
