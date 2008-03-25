#! perl

# $Id: Window.pm,v 1.4 2008/03/25 22:56:48 jv Exp $

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
    $state->set($self->{mew}, $h);
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

sub resize_grid {
    my ($self, $gr) = @_;

    # Calculate minimal fit.
    $gr->AutoSizeColumns(1);

    # Get the total minimal width.
    my $w = 0;
    my @w;
    my $cols = $gr->GetNumberCols;
    for ( 0 .. $cols-1 ) {
	push(@w, $gr->GetColSize($_));
	$w += $w[-1];
    }

    # Get available width.
    my $width;
    if ( $gr->can("GetVirtualSizeWH") ) {
	$width = ($gr->GetVirtualSizeWH)[0];
    }
    else {
	# Assume scrollbar.
	$width = ($gr->GetSizeWH)[0] - 16;
    }

    # Scale columns if possible.
    if ( $w < $width ) {
	my $r = $width / $w;
	for ( 0 .. $cols-1 ) {
	    $gr->SetColSize($_, int($r*$w[$_]));
	}
    }
}

sub EB::Wx::MessageDialog {
    my ($parent, $msg, $title, $flags) = @_;

    $flags ||= wxICON_INFORMATION|wxOK;

    my $m = Wx::MessageDialog->new($parent, $msg, $title, $flags);
    my $ret = $m->ShowModal;
    $m->Destroy;
    return $ret;
}

sub EB::Wx::Fatal {
    my ($msg) = "@_";

    my $m = Wx::MessageDialog->new(undef, $msg,
				   "EekBoek afgebroken",
				   wxICON_ERROR|wxOK);
    my $ret = $m->ShowModal;
    $m->Destroy;
    $app->{TOP}->ExitMainLoop if $app && $app->{TOP};
    exit(1);
}

1;
