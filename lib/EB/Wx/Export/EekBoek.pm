#! perl

use utf8;

package main;

our $state;

package EB::Wx::Export::EekBoek;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;
use EB::Wx::Window;
use EB::Wx::UI::PeriodPanel;
use File::Spec;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Export::EekBoek::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sizer_4_staticbox} = Wx::StaticBox->new($self, -1, "Uitvoeropties" );
	$self->{sizer_6_staticbox} = Wx::StaticBox->new($self, -1, "" );
	$self->{p_period} = EB::Wx::UI::PeriodPanel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{label_1} = Wx::StaticText->new($self, -1, "Omschrijving", wxDefaultPosition, wxDefaultSize, );
	$self->{t_desc} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_single} = Wx::CheckBox->new($self, -1, "Eén regel per boekstuk", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_bsknr} = Wx::CheckBox->new($self, -1, "Expliciteer boekstuknummers", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_explicit} = Wx::CheckBox->new($self, -1, "Expliciteer BTW", wxDefaultPosition, wxDefaultSize, );
	$self->{cb_totals} = Wx::CheckBox->new($self, -1, "Totaalbedragen opnemen", wxDefaultPosition, wxDefaultSize, );
	$self->{b_dir} = Wx::Button->new($self, -1, "Export naar Folder");
	$self->{b_expfile} = Wx::Button->new($self, -1, "Export naar Bestand");
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_dir}->GetId, \&OnExpDir);
	Wx::Event::EVT_BUTTON($self, $self->{b_expfile}->GetId, \&OnExpFile);

# end wxGlade

	$self->{p_period}->allow_all(2);
	$self->{p_period}->Enable(0);
	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Export::EekBoek::__set_properties

	$self->SetTitle("Administratie exporteren");
	$self->{cb_bsknr}->SetValue(1);
	$self->{cb_totals}->SetValue(1);

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Export::EekBoek::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4}= Wx::StaticBoxSizer->new($self->{sizer_4_staticbox}, wxHORIZONTAL);
	$self->{sizer_5} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_7} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_6}= Wx::StaticBoxSizer->new($self->{sizer_6_staticbox}, wxHORIZONTAL);
	$self->{sizer_6}->Add($self->{p_period}, 1, wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{sizer_6}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sizer_7}->Add($self->{label_1}, 0, wxRIGHT|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sizer_7}->Add($self->{t_desc}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{sizer_7}, 1, wxEXPAND, 0);
	$self->{sizer_5}->Add($self->{cb_single}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_bsknr}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_explicit}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_5}->Add($self->{cb_totals}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add($self->{sizer_5}, 1, wxTOP|wxEXPAND, 2);
	$self->{sizer_2}->Add($self->{sizer_4}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 5);
	$self->{sizer_2}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_dir}, 0, wxLEFT|wxTOP|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_expfile}, 0, wxLEFT|wxTOP|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_cancel}, 0, wxALL|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->{sizer_1}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub init {
}

sub refresh {
    my ($self) = @_;
    $self->{p_period}->refresh;
}

sub DoExport {
    my ($self, $path, $file) = @_;

    my $sel = $self->{p_period}->GetValues;

    my $opts = {};

    $opts->{boekjaar} = $sel->{period_panel_bky}
      if $sel->{period_panel_bky} && ! $sel->{period_panel_all};

    if ( defined($path) ) {
	if ( -d $path ) {
	    my $inuse = 0;
	    for ( qw(schema.dat opening.eb muaties.eb relaties.eb) ) {
		$inuse++ if -e File::Spec->catfile($path, $_);
	    }
	    if ( $inuse ) {
		my $ret = EB::Wx::MessageDialog
		  ($self,
		   "De opgegeven folder bevat al exportinformatie.\n".
		   "Moet deze worden overschreven?",
		   "Folder in gebruik",
		   wxICON_ERROR|wxYES_NO|wxNO_DEFAULT);
		return unless $ret == wxID_YES;
	    }
	}
	else {
	    mkdir($path);
	}
	$opts->{dir} = $path;
    }
    else {
	$opts->{file} = $path = $file;
    }

#    $opts->{boekjaar} = ;
    $opts->{desc} = $self->{t_desc}->GetValue;
    $opts->{single} = $self->{cb_single}->GetValue;
    $opts->{bsknr} = $self->{cb_bsknr}->GetValue;
    $opts->{explicit} = $self->{cb_explicit}->GetValue;
    $opts->{totals} = $self->{cb_totals}->GetValue;

    require EB::Export;
    eval { EB::Export->export($opts) };
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
	     "De administratie is succesvol geëxporteerd.",
	     "Succes",
	     wxICON_INFORMATION|wxOK,
	    );
	if ( $opts->{dir} ) {
	    $state->expdir($path);
	}
	else {
	    $state->expfile($path);
	}
    }
    return 1;
}

# wxGlade: EB::Wx::Export::EekBoek::OnExpDir <event_handler>
sub OnExpDir {
    my ($self, $event) = @_;

    my $dd = Wx::DirDialog->new
      ($self,
       "Exporteer naar folder",
       $state->expdir || "",
       wxDD_DEFAULT_STYLE,
       wxDefaultPosition,
      );
    my $res = $dd->ShowModal;
    if ( $res == wxID_OK && $self->DoExport($dd->GetPath, undef) ) {
	$dd->Destroy;
	$self->Destroy;
    }
}

# wxGlade: EB::Wx::Export::EekBoek::OnExpFile <event_handler>
sub OnExpFile {
    my ($self, $event) = @_;

    my $dd = Wx::FileDialog->new
      ($self,
       "Exporteer naar bestand",
       "",
       $state->expfile || "",
       "EekBoek export files (*.ebz)|*.ebz",
       wxFD_SAVE|wxFD_OVERWRITE_PROMPT,
       wxDefaultPosition,
      );
    my $res = $dd->ShowModal;
    if ( $res == wxID_OK && $self->DoExport(undef, $dd->GetPath) ) {
	$dd->Destroy;
	$self->Destroy;
    }

}

# end of class EB::Wx::Export::EekBoek

1;
