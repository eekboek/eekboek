#! perl

# $id$

package main;

our $state;

package EB::Wx::UI::ListInput::ListDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;
use EB;

# begin wxGlade: ::dependencies
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::UI::ListInput::ListDialog::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME|wxSTAY_ON_TOP 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{lb_lst} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize, [], wxLB_SINGLE|wxLB_HSCROLL);
	$self->{b_accept} = Wx::Button->new($self, wxID_OK, "");
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_LISTBOX($self, $self->{lb_lst}->GetId, \&OnSelect);
	Wx::Event::EVT_BUTTON($self, wxID_OK, \&OnOk);
	Wx::Event::EVT_BUTTON($self, wxID_CANCEL, \&OnCancel);

# end wxGlade

	Wx::Event::EVT_CHAR($self, \&OnChar);

	$self->{ctx} = "";
	$self->{ctx_type} = 0;	# 0 = alpha, 1 = numeric
	$self->{default} = "";

	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::UI::ListInput::ListDialog::__set_properties

	$self->SetTitle(_T("Selecteer"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(161, 107)));
	$self->{lb_lst}->SetFocus();
	$self->{lb_lst}->SetSelection(0);
	$self->{b_accept}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::UI::ListInput::ListDialog::__do_layout

	$self->{sz_lstd_outer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_lstd_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_lstd_main}->Add($self->{lb_lst}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_accept}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_cancel}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_lstd_main}->Add($self->{sz_buttons}, 0, wxTOP|wxEXPAND, 5);
	$self->{sz_lstd_outer}->Add($self->{sz_lstd_main}, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_lstd_outer});
	$self->Layout();

# end wxGlade
}

sub setvalue {
    my ($self, $value) = @_;
    my $i = $self->{lb_lst}->FindString($value);
    return if $i < 0;
    $self->{lb_lst}->SetSelection($i);
    $self->{lb_lst}->SetFirstItem($i);
    #$self->{lb_lst}->EnsureVisible($i);
}

sub value {
    my ($self) = @_;
    $self->{lb_lst}->GetSelection;
}

sub fill {
    my ($self, $aref) = @_;
    $self->{lb_lst}->InsertItems($self->{list} = $aref, 0);
}

# wxGlade: EB::Wx::UI::ListInput::ListDialog::OnOk <event_handler>
sub OnOk {
    my ($self, $event) = @_;
    my $v = $1 if $self->{lb_lst}->GetString($self->value) =~ /^(\d+)/;
    $self->closehandler(0+$v);
}

# wxGlade: EB::Wx::UI::ListInput::ListDialog::OnSelect <event_handler>
sub OnSelect {
    my ($self, $event) = @_;
    my $v = $1 if $self->{lb_lst}->GetString($self->value) =~ /^(\d+)/;
    $self->closehandler(0+$v);
}

# wxGlade: EB::Wx::UI::ListInput::ListDialog::OnCancel <event_handler>
sub OnCancel {
    my ($self, $event) = @_;
    $self->closehandler(-1);
}

sub closehandler {
    my ($self, $retval) = @_;
    $self->EndModal($retval);
}

use Wx qw(:keycode);

sub OnChar {
    my ($self, $event) = @_;

    if ( $event->HasModifiers ) {
	# Common controls.
	$event->Skip;
	return;
    }

    # Get key code and char, if ordinary.
    my $k = $event->GetKeyCode;
    my $c = ($k < WXK_START) ? pack("C", $k) : "";

    # Remember default value.
    $self->{default} ||= $self->value;

    if ( $k == WXK_BACK ) {
	# Remove a char from the search.
	if ( $self->{ctx} ne "" ) {
	    chop($self->{ctx});
	    if ( $self->{ctx} eq "" ) {
		# Exhausted -> reset.
		$self->setvalue($self->{default});
	    }
	}
	else {
	    Wx::Bell;
	}
    }
    elsif ( $k == WXK_ESCAPE ) {
	# Reset to orig value.
	$self->setvalue($self->{default});
	$self->{ctx} = "";
    }
    elsif ( $k == WXK_UP ) {
	my $i = $self->{lb_lst}->GetSelection;
	$self->{lb_lst}->SetSelection($i-1) if $i >= 1;
	$self->{ctx} = "";
	$self->{lb_lst}->SetFirstItem($i-1);
    }
    elsif ( $k == WXK_DOWN ) {
	my $i = $self->{lb_lst}->GetSelection;
	$self->{lb_lst}->SetSelection($i+1);
	$self->{ctx} = "";
	$self->{lb_lst}->SetFirstItem($i+1);
    }
    elsif ( $k == WXK_RETURN ) {
	my $v = $1 if $self->{lb_lst}->GetString($self->value) =~ /^(\d+)/;
	$self->closehandler(0+$v);
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
    elsif (
	 $k == WXK_TAB     ||
	 $k >= WXK_START
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
	    $self->setvalue($_);
	    return;
	}
	# No match, remove offending character,
	chop($self->{ctx});
	return;
    }
    else {
    }
#    $event->Skip;
}

# end of class EB::Wx::UI::ListInput::ListDialog

1;

