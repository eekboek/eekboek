package EB::Wx::UI::AmountCtrl;

use Wx qw[:keycodes];
use base qw(Wx::TextCtrl);
use strict;

use EB::Format;

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    Wx::Event::EVT_CHAR($self,        \&OnKbdInput);
    Wx::Event::EVT_KILL_FOCUS($self,  \&OnLoseFocus);
    #Wx::Event::EVT_SET_FOCUS($self,  \&OnGetFocus);
    Wx::Event::EVT_TEXT($self, $self, \&OnChange);
    $self;
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
    my $newval = amount($self->GetValue);
    if ( !defined($newval) ) {
	Wx::Bell;
	$self->SetValue($self->{prev});
	$self->SetInsertionPoint($self->{cursor});
    }
}

sub OnLoseFocus {
    my ($self, $event) = @_;
    my $newval = amount($self->GetValue);
    if ( defined($newval) ) {
	$self->SetValue(numfmt($newval));
    }
    else {
	Wx::Bell;
    }
}

sub OnGetFocus {
    my ($self, $event) = @_;
    # Nothing, yet.
}

1;
