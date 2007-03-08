package EB::Wx::UI::NumericCtrl;

use base qw(Wx::TextCtrl);
use Wx qw[:everything];
use strict;
use EB;

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    Wx::Event::EVT_CHAR($self, \&OnKbdInput);
    $self;
}

sub OnKbdInput {
    my ($self, $event) = @_;
    my $c = $event->GetKeyCode;

    if ( $c == WXK_BACK    ||
	 $c == WXK_TAB     ||
	 $c == WXK_RETURN  ||
	 $c == WXK_ESCAPE  ||
	 $c == WXK_DELETE  ||
	 $c >= WXK_START   ||
	 $event->HasModifiers
       ) {
	$event->Skip;
    }

    elsif ( pack("C", $c) =~ /^\d$/ ) {
	$event->Skip;
    }
    else {
	Wx::Bell;
    }
}

1;
