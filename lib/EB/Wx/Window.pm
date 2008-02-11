#! perl

# $Id: Window.pm,v 1.2 2008/02/11 15:05:07 jv Exp $

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
    my ($self, $posonly) = @_;
    my $h = $state->get($self->{mew});
    @$h{ qw(xpos   ypos  ) } = $self->GetPositionXY;
    @$h{ qw(xwidth ywidth) } = $self->GetSizeWH unless $posonly;
}

sub sizepos_restore {
    my ($self, $mew, $posonly) = @_;
    $self->{mew} = $mew if defined $mew;
    my $h = $state->get($self->{mew});
    $self->Move(    [ @$h{ qw(xpos   ypos  ) } ] )
      if defined($h->{xpos}) && defined($h->{ypos});
    $self->SetSize( [ @$h{ qw(xwidth ywidth) } ] )
      if !$posonly && defined($h->{xwidth}) && defined($h->{ywidth});

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

sub EB::Wx::MessageDialog {
    my ($parent, $msg, $title, $flags) = @_;

    $flags ||= wxICON_INFORMATION|wxOK;

    my $m = Wx::MessageDialog->new($parent, $msg, $title, $flags);
    my $ret = $m->ShowModal;
    $m->Destroy;
    return $ret;
}

1;
