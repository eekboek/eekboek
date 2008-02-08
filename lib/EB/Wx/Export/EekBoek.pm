#! perl

# $Id: EekBoek.pm,v 1.2 2008/02/08 20:27:44 jv Exp $

package main;

our $state;

package EB::Wx::Tools::Export;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;
use EB::Wx::UI::PeriodPanel;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Tools::Export::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sizer_4_staticbox} = Wx::StaticBox->new($self, -1, "Uitvoeropties" );
	$self->{sizer_7_staticbox} = Wx::StaticBox->new($self, -1, "Uitvoerbestemming" );
	$self->{sizer_6_staticbox} = Wx::StaticBox->new($self, -1, "" );
	$self->{p_period} = EB::Wx::UI::PeriodPanel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{cb_single} = Wx::CheckBox->new($self, -1, "Eén regel per boekstuk", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_bsknr} = Wx::CheckBox->new($self, -1, "Expliciteer boekstuknummers", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_explicit} = Wx::CheckBox->new($self, -1, "Expliciteer BTW", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_totals} = Wx::CheckBox->new($self, -1, "Totaalbedragen opnemen", wxDefaultPosition, wxDefaultSize, );
	$self->{l_tofile} = Wx::StaticText->new($self, -1, "Bestand:", wxDefaultPosition, wxDefaultSize, );
	$self->{x_file} = EB::Wx::Tools::Export::FilePicker->new($self, -1, "label_2", wxDefaultPosition, wxDefaultSize, );
	$self->{l_tofolder} = Wx::StaticText->new($self, -1, "Folder:", wxDefaultPosition, wxDefaultSize, );
	$self->{x_dir} = EB::Wx::Tools::Export::DirPicker->new($self, -1, "label_1", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_dir} = Wx::CheckBox->new($self, -1, "Exporteer naar folder", wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");
	$self->{b_accept} = Wx::Button->new($self, wxID_OK, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_CHECKBOX($self, $self->{cb_dir}->GetId, \&OnDirFile);
	Wx::Event::EVT_BUTTON($self, $self->{b_accept}->GetId, \&OnAccept);

# end wxGlade

	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::Export::__set_properties

	$self->SetTitle("Administratie exporteren");
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(200, 222)));
	$self->{cb_bsknr}->SetValue(1);
	$self->{cb_totals}->SetValue(1);
	$self->{l_tofolder}->Show(0);
	$self->{x_dir}->Show(0);

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::Export::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_7}= Wx::StaticBoxSizer->new($self->{sizer_7_staticbox}, wxHORIZONTAL);
	$self->{sz_out} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_todir} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_tofile} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4}= Wx::StaticBoxSizer->new($self->{sizer_4_staticbox}, wxHORIZONTAL);
	$self->{sizer_5} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_6}= Wx::StaticBoxSizer->new($self->{sizer_6_staticbox}, wxHORIZONTAL);
	$self->{sizer_6}->Add($self->{p_period}, 1, wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{sizer_6}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sizer_5}->Add($self->{cb_single}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_bsknr}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_explicit}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_totals}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add($self->{sizer_5}, 0, wxTOP|wxEXPAND, 2);
	$self->{sizer_2}->Add($self->{sizer_4}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 5);
	$self->{sz_tofile}->Add($self->{l_tofile}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sz_tofile}->Add($self->{x_file}, 1, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sz_out}->Add($self->{sz_tofile}, 1, wxTOP|wxEXPAND, 2);
	$self->{sz_todir}->Add($self->{l_tofolder}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sz_todir}->Add($self->{x_dir}, 1, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sz_out}->Add($self->{sz_todir}, 1, wxTOP|wxEXPAND, 2);
	$self->{sz_out}->Add(2, 2, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_out}->Add($self->{cb_dir}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{sz_out}, 1, wxLEFT|wxRIGHT|wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{sizer_7}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 5);
	$self->{sizer_2}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_cancel}, 0, wxLEFT|wxTOP|wxBOTTOM|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_accept}, 0, wxALL|wxADJUST_MINSIZE, 5);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();

# end wxGlade
}

sub init {
}

sub refresh {
    my ($self) = @_;
    $self->{p_period}->refresh;
}

# wxGlade: EB::Wx::Tools::Export::OnDirFile <event_handler>
sub OnDirFile {
    my ($self, $event) = @_;

    if ( $self->{cb_dir}->GetValue ) {
	$self->{sz_out}->Show($self->{sz_tofile}, 0, 1);
	$self->{sz_out}->Show($self->{sz_todir}, 1, 1);
    }
    else {
	$self->{sz_out}->Show($self->{sz_todir}, 0, 1);
	$self->{sz_out}->Show($self->{sz_tofile}, 1, 1);
    }
    $self->Layout();

}

# wxGlade: EB::Wx::Tools::Export::OnAccept <event_handler>
sub OnAccept {
    my ($self, $event) = @_;

    my $opts = {};
    my $path;

    if ( $self->{cb_dir}->GetValue ) {
	$path = $opts->{dir} = $self->{x_dir}->GetPath;
	if ( -d $state->expdir ) {
	    my $inuse = 0;
	    for ( qw(schema.dat opening.eb muaties.eb relaties.eb) ) {
		$inuse++ if -e $_;
	    }
	    if ( $inuse ) {
		my $ret = Wx::MessageBox
		  ("De opgegeven folder bevat al exportinformatie.\n".
		   "Moet deze worden overschreven?",
		   "Folder in gebruik",
		   wxICON_ERROR|wxYES_NO|wxNO_DEFAULT);
		return unless $ret == wxYES;
	    }
	}
	else {
	    mkdir($state->expdir);
	}
    }
    else {
	$path = $opts->{file} = $self->{x_file}->GetPath;
	if ( -e $path ) {
	    # This should be handled by wxFLP_OVERWRITE_PROMPT...
	    my $ret = Wx::MessageBox
	      ("Het opgegeven exportbestand bestaat al.\n".
	       "Moet dit bestand worden overschreven?",
	       "File bestaat al",
	       wxICON_ERROR|wxYES_NO|wxNO_DEFAULT);
	    return unless $ret == wxYES;
	}
    }

#    $opts->{boekjaar} = ;
    $opts->{single} = $self->{cb_single}->GetValue;
    $opts->{bsknr} = $self->{cb_bsknr}->GetValue;
    $opts->{explicit} = $self->{cb_explicit}->GetValue;
    $opts->{totals} = $self->{cb_totals}->GetValue;

    require EB::Export;
    eval { EB::Export->export($opts) };
    if ( $@ ) {
	Wx::LogMessage($@);
	Wx::MessageBox
	    ("Fout tijdens het exporteren:\n".$@,
	     "Fout tijdens het exporteren",
	     wxICON_ERROR|wxOK);
    }
    else {
	Wx::LogMessage("Export: $path");
	Wx::MessageBox
	    ("De administratie is succesvol geëxporteerd.",
	     "Succes",
	     wxICON_INFORMATION|wxOK,
	    );
	if ( $self->{cb_dir}->GetValue ) {
	    $state->expdir($path);
	}
	else {
	    $state->expfile($path);
	}
    }
    $event->Skip;
}

# end of class EB::Wx::Tools::Export

package EB::Wx::Tools::Export::FilePicker;

use strict;
use base qw(Wx::FilePickerCtrl);

use Wx qw(:everything);

sub new {
    my ($self, $parent, $id, $title, $pos, $size) = @_;
    $self->SUPER::new
      ($parent, $id,
       $state->expfile || "",
       "Exporteer naar bestand",
       "EekBoek export files (*.ebz)|*.ebz",
       $pos || wxDefaultPosition,
       $size || wxDefaultSize,
       wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|
       wxFLP_SAVE|wxFLP_OVERWRITE_PROMPT,
       wxDefaultValidator,
       "name"
      );

}

package EB::Wx::Tools::Export::DirPicker;

use strict;
use base qw(Wx::DirPickerCtrl);

use Wx qw(:everything);

sub new {
    my ($self, $parent, $id, $title, $pos, $size) = @_;
    $self->SUPER::new
      ($parent, $id,
       $state->expdir || "",
       "Exporteer naar folder",
       $pos || wxDefaultPosition,
       $size || wxDefaultSize,
       wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER
      );

}

1;
