#! perl

# $Id: StdAccounts.pm,v 1.6 2008/02/08 20:27:44 jv Exp $

package main;

our $dbh;
our $state;
our $app;

package EB::Wx::Maint::StdAccounts;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;
use EB;

# begin wxGlade: ::dependencies
use EB::Wx::UI::StdAccPanel;
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Maint::StdAccounts::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{stdacc_title_staticbox} = Wx::StaticBox->new($self, -1, _T("Koppelingen") );
	$self->{p_stdacc} = EB::Wx::UI::StdAccPanel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{l_inuse} = Wx::StaticText->new($self, -1, _T("Sommige gegevens zijn in gebruik en\nkunnen niet meer worden gewijzigd."), wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnClose);

# end wxGlade
	return $self;

}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::StdAccounts::__set_properties

	$self->SetTitle(_T("Koppelingen"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(238, 195)));
	$self->{b_cancel}->SetFocus();
	$self->{b_cancel}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::StdAccounts::__do_layout

	$self->{stdacc_outer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{stdacc_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{stdacc_title}= Wx::StaticBoxSizer->new($self->{stdacc_title_staticbox}, wxHORIZONTAL);
	$self->{stdacc_title}->Add($self->{p_stdacc}, 1, wxEXPAND, 0);
	$self->{stdacc_main}->Add($self->{stdacc_title}, 1, wxEXPAND, 0);
	$self->{sz_buttons}->Add($self->{l_inuse}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_cancel}, 0, wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 5);
	$self->{stdacc_main}->Add($self->{sz_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->{stdacc_outer}->Add($self->{stdacc_main}, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{stdacc_outer});
	$self->Layout();

# end wxGlade
}

# wxGlade: EB::Wx::Maint::StdAccounts::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    if ( $self->{p_stdacc}->changed ) {
	my $r = Wx::MessageBox("Er zijn nog wijzigingen, deze zullen verloren gaan.\n".
			       "Venster toch sluiten?",
			       "Annuleren",
			       wxYES_NO|wxNO_DEFAULT|wxICON_ERROR);
	return unless $r == wxYES;
	$self->{p_stdacc}->refresh;
    }
    # Remember position and size.
    $self->sizepos_save;
    # Disappear.
    $self->Show(0);
}

# end of class EB::Wx::Maint::StdAccounts

1;

