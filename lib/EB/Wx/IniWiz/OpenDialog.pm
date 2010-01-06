#!/usr/bin/perl -w -- 

use Wx 0.15 qw[:allclasses];
use strict;
use utf8;

package EB::Wx::IniWiz::OpenDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;
use EB qw(_T);

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::IniWiz::OpenDialog::new

	$style = wxDEFAULT_DIALOG_STYLE 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{label_1} = Wx::StaticText->new($self, -1, _T("Beschikbare administraties"), wxDefaultPosition, wxDefaultSize, );
	$self->{lb_adm} = Wx::ListBox->new($self, -1, wxDefaultPosition, wxDefaultSize, [], wxLB_SINGLE);
	$self->{b_new} = Wx::Button->new($self, wxID_NEW, "");
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");
	$self->{b_accept} = Wx::Button->new($self, wxID_OK, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_LISTBOX_DCLICK($self, $self->{lb_adm}->GetId, \&OnSelectAndGo);
	Wx::Event::EVT_BUTTON($self, $self->{b_new}->GetId, \&OnCreate);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_accept}->GetId, \&OnOpen);

# end wxGlade

	return $self;

}

sub init {
    my ( $self, $dirs ) = @_;

    $self->{lb_adm}->Append($dirs);
    $self->{lb_adm}->SetSelection(0);
    $self->{b_accept}->SetFocus if @$dirs == 1;
}

sub GetSelection {
    my ( $self ) = @_;
    $self->{lb_adm}->GetSelection;
}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::IniWiz::OpenDialog::__set_properties

	$self->SetTitle(_T("Administratiekeuze"));
	$self->SetSize(Wx::Size->new(440, 240));
	$self->{lb_adm}->SetSelection(0);

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::IniWiz::OpenDialog::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2}->Add($self->{label_1}, 0, wxBOTTOM|wxADJUST_MINSIZE, 5);
	$self->{sizer_2}->Add($self->{lb_adm}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add(5, 5, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add(5, 5, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_new}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_cancel}, 0, wxLEFT|wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_accept}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();

# end wxGlade
}

sub OnCreate {
	my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OpenDialog::OnCreate <event_handler>

	$self->EndModal( wxID_NEW );

# end wxGlade
}

sub OnCancel {
	my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OpenDialog::OnCancel <event_handler>

	$self->EndModal( wxID_CANCEL );

# end wxGlade
}

sub OnOpen {
	my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OpenDialog::OnOpen <event_handler>

	$self->EndModal( wxID_OK );

# end wxGlade
}

sub OnSelectAndGo {
	my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OpenDialog::OnSelectAndGo <event_handler>

	$self->EndModal( wxID_OK );

# end wxGlade
}

# end of class EB::Wx::IniWiz::OpenDialog

1;
