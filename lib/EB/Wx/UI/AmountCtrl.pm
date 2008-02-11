#! perl

# $Id: AmountCtrl.pm,v 1.4 2008/02/11 15:22:19 jv Exp $

package EB::Wx::UI::AmountCtrl;

use Wx qw[:everything];
use base qw(Wx::TextCtrl);
use base qw(Wx::PlWindow);
use base qw(Exporter);
our @EXPORT_OK = qw(EVT_PL_AMOUNT);
our %EXPORT_TAGS = ( 'everything'   => \@EXPORT_OK,
                     'event'        => [ qw(EVT_PL_AMOUNT) ],
		   );

use strict;

use EB::Format qw(numfmt amount);

sub new {
    my ($class, @args) = @_;
    $args[5] |= wxTE_RIGHT;
    my $self = $class->SUPER::new(@args);
    Wx::Event::EVT_CHAR($self,        \&OnKbdInput);
    Wx::Event::EVT_KILL_FOCUS($self,  \&OnLoseFocus);
    #Wx::Event::EVT_SET_FOCUS($self,  \&OnGetFocus);
    Wx::Event::EVT_TEXT($self, $self, \&OnChange);
    $self;
}

my $evt_change = Wx::NewEventType;

sub Wx::Event::EVT_PL_AMOUNT($$$) {
    $_[0]->Connect($_[1], -1, $evt_change, $_[2]);
}

sub SetValue {
    my ($self, $value) = @_;
    $self->SUPER::SetValue(numfmt($value));
}

sub GetValue {
    my ($self) = @_;
    amount($self->SUPER::GetValue);
}

sub OnKbdInput {
    my ($self, $event) = @_;
    my $c = $event->GetKeyCode;
    $self->{prev} = $self->GetValue;
    $self->{cursor} = $self->GetInsertionPoint;

    if ( $c == WXK_TAB     ||
	 $c == WXK_RETURN  ||
	 $c == WXK_BACK    ||
	 $c == WXK_DELETE  ||
	 $c >= WXK_START   ||
	 $event->HasModifiers
       ) {
	$event->Skip;
	return;
    }

    my $chr = pack("C", $c);
    if ( $chr =~ /^[[:digit:]]$/ ) {
	$event->Skip;
    }
    elsif ( $chr =~ /^[.,]$/ ) {
	if ( $self->{prev} =~ /[.,]/ ) {
	    Wx::Bell;
	}
	else {
	    $event->Skip;
	}
    }
    else {
	Wx::Bell;
    }
}

sub OnChange {
    my ($self, $event) = @_;
    my $newval = $self->GetValue;
    if ( !defined($newval) ) {
	Wx::Bell;
	$self->SetValue($self->{prev});
	$self->SetInsertionPoint($self->{cursor});
    }

    my $event =
      EB::Wx::Perl::AmountCtrl::Event->new($evt_change, $self->GetId);
    $self->GetEventHandler->ProcessEvent($event);

}

sub OnLoseFocus {
    my ($self, $event) = @_;
    my $newval = $self->GetValue;
    if ( defined($newval) ) {
	$self->SetValue($newval);
    }
    else {
	Wx::Bell;
    }
}

sub OnGetFocus {
    my ($self, $event) = @_;
    # Nothing, yet.
}

package EB::Wx::Perl::AmountCtrl::Event;
use base qw(Wx::PlCommandEvent);

1;
