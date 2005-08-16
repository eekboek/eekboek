package main;

our $dbh;
our $config;
our $app;

package AccInput;

use Wx qw(wxDefaultPosition wxDefaultSize);
use base qw(Wx::ComboBox);
use strict;

sub new {
    my ($self, $parent, $id, $title, $pos, $size ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $title  = ""                 unless defined $title;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;

    my $accts = $dbh->accts;
    $accts = [ map { $_ . "   " . $accts->{$_} } sort { $a <=> $b } keys %$accts ];

    $self = $self->SUPER::new($parent, -1, "", wxDefaultPosition, wxDefaultSize, $accts, );

    $self->{accts} = $accts;

    Wx::Event::EVT_CHAR($self, \&OnChar);
    Wx::Event::EVT_COMBOBOX($self, $self->GetId, \&OnSelect);
    Wx::Event::EVT_KILL_FOCUS($self, \&OnLoseFocus);

    $self->{ctx} = "";
    return $self;
}

use Wx qw(:keycode);

sub OnChar {
    my ($self, $event) = @_;
    my $k = $event->GetKeyCode;
    my $c = ($k < WXK_START) ? pack("C", $k) : "";

    if ( $k == WXK_BACK ) {
	if ( $self->{ctx} ne "" ) {
	    chop($self->{ctx});
	}
	else {
	    Wx::Bell;
	}
    }
    elsif ( $c =~ /^[[:alpha:]]$/ ) {
	if ( $self->{ctx} =~ /^[[:digit:]]+$/ ) {
	    $self->{ctx} = $c;
	}
	else {
	    $self->{ctx} .= $c;
	}
    }
    elsif ( $c =~ /^[[:digit:]]$/ ) {
	if ( $self->{ctx} =~ /^[[:digit:]]+$/ ) {
	    $self->{ctx} .= $c;
	}
	else {
	    $self->{ctx} = $c;
	}
    }
    else {
	$event->Skip;
    }
    if ( $self->{ctx} ne "" ) {
	my $lk = $self->{ctx};
	my $pat = ($lk =~ /^[[:digit:]]+$/) ? qr/^$lk/ : qr/^\S+\s+$lk/i;
	foreach ( @{$self->{accts}} ) {
	    next unless /$pat/;
	    $self->SetValue($_);
	    return;
	}
	return;
    }
    $event->Skip;
}

# wxGlade: MyFrame::OnSelect <event_handler>
sub OnSelect {
    my ($self, $event) = @_;
    $self->{ctx} = "";
    $event->Skip;
}

# wxGlade: MyFrame::OnLoseFocus <event_handler>
sub OnLoseFocus {
    my ($self, $event) = @_;
    my $obj = $event->GetEventObject;
    #warn("Selected: ", $obj->GetValue);
}

1;
