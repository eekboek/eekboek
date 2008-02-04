#! perl

# $Id: ListInput.pm,v 1.3 2008/02/04 23:25:49 jv Exp $

package main;

our $dbh;
our $state;
our $app;

package EB::Wx::UI::ListInput;

use Wx qw(wxDefaultPosition wxDefaultSize wxID_OK);
use base qw(Wx::TextCtrl);
use strict;
use EB;

sub new {
    my ($self, $parent, $id, $title, $pos, $size, $style, $list ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $title  = ""                 unless defined $title;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;
    $style = 0			 unless defined $style;

    my $class = ref($self) || $self;
    $self = $self->SUPER::new($parent, -1, "", $pos, $size, $style );

    $self->{list} = $list;

    Wx::Event::EVT_CHAR($self, \&OnChar);
    Wx::Event::EVT_LISTBOX($self, $self->GetId, \&OnSelect);

    Wx::Event::EVT_IDLE($self, \&OnIdle);

    $self->{ctx} = "";
    $self->{ctx_type} = 0;	# 0 = alpha, 1 = numeric
    $self->{default} = "";
    return $self;
}

use Wx qw(:keycode);

sub OnChar {
    my ($self, $event) = @_;

    # Get key code and char, if ordinary.
    my $k = $event->GetKeyCode;
    my $c = ($k < WXK_START) ? pack("C", $k) : "";

    # Remember default value.
    $self->{default} ||= $self->SUPER::GetValue;

    if ( $k == WXK_BACK ) {
	# Remove a char from the search.
	if ( $self->{ctx} ne "" ) {
	    chop($self->{ctx});
	    if ( $self->{ctx} eq "" ) {
		# Exhausted -> reset.
		$self->SetValue($self->{default});
	    }
	}
	else {
	    Wx::Bell;
	}
    }
    elsif ( $k == WXK_ESCAPE ) {
	# Reset to orig value.
	$self->SUPER::SetValue($self->{default});
	$self->{ctx} = "";
    }
    elsif ( $k == WXK_UP ) {
	my $v;
	my $cur = $self->SUPER::GetValue;
	foreach ( @{$self->{list}} ) {
	    last if $_ eq $cur;
	    $v = $_;
	}
	$self->SUPER::SetValue($v) if $v;
	$self->{ctx} = "";
    }
    elsif ( $k == WXK_DOWN ) {
	my $v = "";
	my $cur = $self->SUPER::GetValue;
	foreach ( @{$self->{list}} ) {
	    if ( $v eq $cur ) {
#		$self->SUPER::SetValue($_);
		$self->{_pending} = $_;
		last;
	    }
	    $v = $_;
	}
	$self->{ctx} = "";
    }
    elsif ( $c =~ /^[[:alpha:]]$/ ) {
	# Append to search, or switch search type.
	if ( $self->{ctx_type} ) {
	    $self->{ctx} = $c;
	    $self->{ctx_type} = 0;
	}
	else {
	    $self->{ctx} .= $c;
	}
    }
    elsif ( $c =~ /^[[:digit:]]$/ ) {
	# Append to search, or switch search type.
	if ( $self->{ctx_type} ) {
	    $self->{ctx} .= $c;
	}
	else {
	    $self->{ctx} = $c;
	    $self->{ctx_type} = 1;
	}
    }
    elsif ( $c eq '?' ) {
	use EB::Wx::UI::ListInput::ListDialog;
	my $d = EB::Wx::UI::ListInput::ListDialog->new($self, -1, "Selecteer", wxDefaultPosition, wxDefaultSize,);
	$d->fill($self->{list});
	$d->setvalue($self->SUPER::GetValue);
	my $ret = $d->ShowModal;
	$self->SetValue($ret) if $ret >= 0;
	$d->Destroy;
    }
    elsif (
	 $k == WXK_TAB     ||
	 $k == WXK_RETURN  ||
	 $k >= WXK_START   ||
	 $event->HasModifiers
       ) {
	# Common controls.
	$event->Skip;
	return;
    }
    else {
	# Skip event.
    }

    # Try to match.
    if ( $self->{ctx} ne "" ) {
	my $lk = $self->{ctx};
	my $pat = $self->{ctx_type} ? qr/(^)($lk)/ : qr/^(\S+\s+)($lk)/i;
	foreach ( @{$self->{list}} ) {
	    next unless /$pat/;
	    $self->SUPER::SetValue($_);
	    $self->SetSelection(length($1), length($1)+length($2));
	    return;
	}
	# No match, remove offendig character,
	chop($self->{ctx});
	return;
    }
    else {
	$self->SetSelection(0,0);
    }
#    $event->Skip;
}

sub OnIdle {
    my ($self) = @_;
    return unless defined $self->{_pending};
    $self->SetValue(delete $self->{_pending});
}

# Value setter/getters. These use the numeric part only.

sub SetValue {
    my ($self, $value) = @_;
    foreach ( @{$self->{list}} ) {
	next unless /^(\d+)/ && $1 == $value;
	$value = $_;
	last;
    }
    $self->SUPER::SetValue($value);
}

sub GetValue {
    my ($self) = @_;
    my $value = $self->SUPER::GetValue;
    $value =~ /^(\d+)/;
    $1;				# valid or undef
}

# wxGlade: MyFrame::OnSelect <event_handler>
sub OnSelect {
    my ($self, $event) = @_;
    $self->{ctx} = "";
    $self->{ctx_type} = 0;
    $event->Skip;
}

# wxGlade: MyFrame::OnLoseFocus <event_handler>
sub OnLoseFocus {
    my ($self, $event) = @_;
    my $obj = $event->GetEventObject;
    #warn("Selected: ", $obj->GetValue);
}

1;
