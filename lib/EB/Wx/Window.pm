#! perl

# $Id: Window.pm,v 1.1 2008/02/04 23:09:01 jv Exp $

package main;

our $cfg;
our $state;
our $app;
our $dbh;

package EB::Wx::Window;

use strict;
use warnings;

use Wx qw(:everything);

sub sizepos_save {
    my ($self) = @_;
    my $h = $state->get($self->{mew});
    @$h{ qw(xpos   ypos  ) } = $self->GetPositionXY;
    @$h{ qw(xwidth ywidth) } = $self->GetSizeWH;
}

sub sizepos_restore {
    my ($self, $mew) = @_;
    $self->{mew} = $mew if defined $mew;
    my $h = $state->get($self->{mew});
    $self->Move(    [ @$h{ qw(xpos   ypos  ) } ] );
    $self->SetSize( [ @$h{ qw(xwidth ywidth) } ] );

    # For convenience: CLOSE on Ctrl-W and Esc.
    # (Doesn't work on GTK, yet).
    $self->SetAcceleratorTable
      (Wx::AcceleratorTable->new
       ( [wxACCEL_CTRL, ord 'w', wxID_CLOSE],
	 [wxACCEL_NORMAL, 27, wxID_CLOSE],
       ));

}

sub set_status {
    my ($self, $text, $ix) = @_;
    return unless $app && $app->{TOP} && $app->{TOP}->{mainframe_statusbar};
    $app->{TOP}->{mainframe_statusbar}->SetStatusText($text, $ix||0);
}

#### Override
sub init {
    shift->refresh(@_);
}

#### Override
sub refresh {
}

1;
