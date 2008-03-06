#! perl

# $Id: Openstaand.pm,v 1.2 2008/03/06 14:36:36 jv Exp $

package main;

our $state;

package EB::Wx::Report::Openstaand;

use base qw(EB::Wx::Report::GenBase);
use strict;
use EB;

sub init {
    my ($self, $me) = @_;
    $self->SetDetails(0,0,0);
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    my $output = "<h1>Output</h1>";
    $self->html->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

1;

