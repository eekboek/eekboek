#! perl

# $Id: NumericCtrl.pm,v 1.4 2008/02/04 23:25:49 jv Exp $

package EB::Wx::UI::NumericCtrl;

use base qw(Wx::TextCtrl);
use Wx qw[:everything];
use Wx::Perl::TextValidator;
use strict;
use EB;

sub new {
    my ($class, @args) = @_;
    my $self = $class->SUPER::new(@args);
    $self->SetValidator(Wx::Perl::TextValidator->new(qr/\d/));
    $self;
}

1;

__END__

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
