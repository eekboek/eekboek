#! perl --			-*- coding: utf-8 -*-

use utf8;

# $Id: XAF.pm,v 1.2 2009/10/14 21:14:02 jv Exp $

package main;

our $state;

package EB::Wx::Export::XAF;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;
use EB::Wx::Window;
use EB::Wx::UI::PeriodPanel;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Export::XAF::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_opts_staticbox} = Wx::StaticBox->new($self, -1, "Uitvoeropties" );
	$self->{sizer_6_staticbox} = Wx::StaticBox->new($self, -1, "" );
	$self->{p_period} = EB::Wx::UI::PeriodPanel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{cb_single} = Wx::CheckBox->new($self, -1, "Eén regel per boekstuk", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_bsknr} = Wx::CheckBox->new($self, -1, "Expliciteer boekstuknummers", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_explicit} = Wx::CheckBox->new($self, -1, "Expliciteer BTW", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_totals} = Wx::CheckBox->new($self, -1, "Totaalbedragen opnemen", wxDefaultPosition, wxDefaultSize, );
	$self->{b_expfile} = Wx::Button->new($self, wxID_SAVE, "");
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_expfile}->GetId, \&OnExpFile);

# end wxGlade

	$self->{p_period}->allow_all(0);
	$self->{p_period}->allow_fromto(0);
#	$self->{p_period}->Enable(0);
	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Export::XAF::__set_properties

	$self->SetTitle("Aanmaken XML Audit File");
	$self->{cb_bsknr}->SetValue(1);
	$self->{cb_totals}->SetValue(1);

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Export::XAF::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_opts}= Wx::StaticBoxSizer->new($self->{sz_opts_staticbox}, wxHORIZONTAL);
	$self->{sizer_5} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_6}= Wx::StaticBoxSizer->new($self->{sizer_6_staticbox}, wxHORIZONTAL);
	$self->{sizer_6}->Add($self->{p_period}, 1, wxEXPAND, 0);
	$self->{sz_main}->Add($self->{sizer_6}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sizer_5}->Add($self->{cb_single}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_bsknr}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_explicit}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_totals}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_opts}->Add($self->{sizer_5}, 0, wxTOP|wxEXPAND, 2);
	$self->{sz_main}->Add($self->{sz_opts}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 5);
	$self->{sz_main}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_expfile}, 0, wxLEFT|wxTOP|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_cancel}, 0, wxALL|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_main}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sz_main}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->{sizer_1}->Fit($self);
	$self->Layout();

# end wxGlade

	$self->{sz_main}->Show($self->{sz_opts}, 0);
	$self->Layout;

}

sub init {
}

sub refresh {
    my ($self) = @_;
    $self->{p_period}->refresh;
}

sub DoExport {
    my ($self, $path) = @_;

    my $sel = $self->{p_period}->GetValues;

    my $opts = {};

    $opts->{boekjaar} = $sel->{period_panel_bky}
      if $sel->{period_panel_bky} && ! $sel->{period_panel_all};

    $opts->{xaf} = $path;

    require EB::Export::XAF;
    eval { EB::Export::XAF->export($opts) };
    if ( $@ ) {
	Wx::LogMessage($@);
	EB::Wx::MessageDialog
	    ($self,
	     "Fout tijdens het exporteren:\n".$@,
	     "Fout tijdens het exporteren",
	     wxICON_ERROR|wxOK);
	return;
    }
    else {
	Wx::LogMessage("Export: $path");
	EB::Wx::MessageDialog
	    ($self,
	     "De XML Audit File is succesvol aangemaakt.",
	     "Succes",
	     wxICON_INFORMATION|wxOK,
	    );
	$state->expxaf($path);
    }
    return 1;
}

# wxGlade: EB::Wx::Export::XAF::OnExpFile <event_handler>
sub OnExpFile {
    my ($self, $event) = @_;

    my $dd = Wx::FileDialog->new
      ($self,
       "Aanmaken XML Audit File",
       "",
       $state->expxaf || "",
       "XML Audit files (*.xaf)|*.xaf",
       wxFD_SAVE|wxFD_OVERWRITE_PROMPT,
       wxDefaultPosition,
      );
    my $res = $dd->ShowModal;
    if ( $res == wxID_OK && $self->DoExport($dd->GetPath) ) {
	$dd->Destroy;
	$self->Destroy;
    }

}

# end of class EB::Wx::Export::XAF

1;
