#! perl

package main;

our $cfg;
our $dbh;
our $state;

package Wx::DatePickerCtrl;

package EB::Wx::Booking::IVPanel::BskPanel;

use Wx qw[:everything :datepicker];
use Wx::Calendar;
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;
use EB;
use EB::Format;
use EB::Booking;
use EB::Wx::UI::AmountCtrl;
use EB::Wx::UI::BTWInput;
use EB::Wx::UI::AccInput;
use Wx::Grid;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Booking::IVPanel::BskPanel::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_bsrs_staticbox} = Wx::StaticBox->new($self, -1, _T("Boekstukregels") );
	$self->{sz_bsr_staticbox} = Wx::StaticBox->new($self, -1, _T("Details boekstukregel") );
	$self->{sz_bsk_staticbox} = Wx::StaticBox->new($self, -1, _T("Boekstuk") );
	$self->{label_4} = Wx::StaticText->new($self, -1, _T("Volgnr."), wxDefaultPosition, wxDefaultSize, );
	$self->{label_6} = Wx::StaticText->new($self, -1, _T("Omschrijving"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_bsknr} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_RIGHT);
	$self->{t_desc} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{label_1} = Wx::StaticText->new($self, -1, _T("Relatie"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_rel_code} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{t_rel_desc} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{label_5} = Wx::StaticText->new($self, -1, _T("Datum"), wxDefaultPosition, wxDefaultSize, );
	$self->{dt_date} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{b_date} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("calendar.png", wxBITMAP_TYPE_ANY));
	$self->{label_2} = Wx::StaticText->new($self, -1, _T("Bedrag"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_3} = Wx::StaticText->new($self, -1, _T("Referentie"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_amount} = EB::Wx::UI::AmountCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_RIGHT);
	$self->{t_ref} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{static_line_1} = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLI_VERTICAL);
	$self->{b_apply} = Wx::Button->new($self, -1, _T("Toepassen"));
	$self->{b_cancel} = Wx::Button->new($self, -1, _T("Annuleren"));
	$self->{b_forward} = Wx::Button->new($self, -1, _T("Volgende"));
	$self->{b_backward} = Wx::Button->new($self, -1, _T("Vorige"));
	$self->{gr_bsr} = Wx::Grid->new($self, -1);
	$self->{b_add} = Wx::Button->new($self, -1, _T("Toevoegen"));
	$self->{b_dupl} = Wx::Button->new($self, -1, _T("Dupliceren"));
	$self->{b_change} = Wx::Button->new($self, -1, _T("Wijzigen"));
	$self->{b_remove} = Wx::Button->new($self, -1, _T("Verwijderen"));
	$self->{l_bsr_total} = Wx::StaticText->new($self, -1, _T("Totaal boekstukregels: "), wxDefaultPosition, wxDefaultSize, );
	$self->{label_12} = Wx::StaticText->new($self, -1, _T("Datum"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_13} = Wx::StaticText->new($self, -1, _T("Omschrijving"), wxDefaultPosition, wxDefaultSize, );
	$self->{td_r_date} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{b_r_date} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("calendar.png", wxBITMAP_TYPE_ANY));
	$self->{t_r_desc} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{l_amount1} = Wx::StaticText->new($self, -1, _T("Bedrag"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_r_amount} = EB::Wx::UI::AmountCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_RIGHT);
	$self->{label_14} = Wx::StaticText->new($self, -1, _T("BTW"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_15} = Wx::StaticText->new($self, -1, _T("Soort"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_r_btw} = EB::Wx::UI::BTWInput->new($self, -1, wxDefaultPosition, wxDefaultSize, [], );
	$self->{t_r_btw} = EB::Wx::UI::AmountCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_RIGHT);
	$self->{c_r_kstomz} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, [_T("Kosten"), _T("Neutraal"), _T("Omzet")], );
	$self->{l_amount2} = Wx::StaticText->new($self, -1, _T("Bedrag"), wxDefaultPosition, wxDefaultSize, wxALIGN_RIGHT);
	$self->{label_10} = Wx::StaticText->new($self, -1, _T("Rekening"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_r_amount2} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_RIGHT);
	$self->{t_r_acct} = EB::Wx::UI::AccInput->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{static_line_2} = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, wxLI_VERTICAL);
	$self->{b_r_accept} = Wx::Button->new($self, -1, _T("Toepassen"));
	$self->{b_r_cancel} = Wx::Button->new($self, -1, _T("Annuleren"));
	$self->{b_r_forward} = Wx::Button->new($self, -1, _T("Volgende"));
	$self->{b_r_backward} = Wx::Button->new($self, -1, _T("Vorige"));
	$self->{cb_pin} = Wx::CheckBox->new($self, -1, _T("Toon details tegelijk met boekstukregels"), wxDefaultPosition, wxDefaultSize, );

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_date}->GetId, \&OnDate);
	Wx::Event::EVT_BUTTON($self, $self->{b_apply}->GetId, \&OnApply);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_forward}->GetId, \&OnForward);
	Wx::Event::EVT_BUTTON($self, $self->{b_backward}->GetId, \&OnBackward);
	Wx::Event::EVT_BUTTON($self, $self->{b_add}->GetId, \&OnAdd);
	Wx::Event::EVT_BUTTON($self, $self->{b_dupl}->GetId, \&OnDupl);
	Wx::Event::EVT_BUTTON($self, $self->{b_change}->GetId, \&OnChange);
	Wx::Event::EVT_BUTTON($self, $self->{b_remove}->GetId, \&OnRemove);
	Wx::Event::EVT_BUTTON($self, $self->{b_r_date}->GetId, \&OnRDate);
	Wx::Event::EVT_CHOICE($self, $self->{c_r_btw}->GetId, \&OnRBTW);
	Wx::Event::EVT_CHOICE($self, $self->{c_r_kstomz}->GetId, \&OnRKstOmz);
	Wx::Event::EVT_BUTTON($self, $self->{b_r_accept}->GetId, \&OnRApply);
	Wx::Event::EVT_BUTTON($self, $self->{b_r_cancel}->GetId, \&OnRCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_r_forward}->GetId, \&OnRForward);
	Wx::Event::EVT_BUTTON($self, $self->{b_r_backward}->GetId, \&OnRBackward);
	Wx::Event::EVT_CHECKBOX($self, $self->{cb_pin}->GetId, \&OnPin);

# end wxGlade

	Wx::Event::EVT_GRID_CELL_LEFT_CLICK($self->{gr_bsr}, \&OnClick);
	Wx::Event::EVT_GRID_CELL_LEFT_DCLICK($self->{gr_bsr}, \&OnDClick);

	return $self;

}


sub __set_properties {
	my $self = shift;

	$self->{td_r_date}->SetMinSize($self->{td_r_date}->ConvertDialogSizeToPixels(Wx::Size->new(44, -1)));
	$self->{t_r_amount}->SetMinSize($self->{t_r_amount}->ConvertDialogSizeToPixels(Wx::Size->new(60, -1)));
	$self->{t_r_btw}->SetMinSize($self->{t_r_btw}->ConvertDialogSizeToPixels(Wx::Size->new(60, -1)));

# begin wxGlade: EB::Wx::Booking::IVPanel::BskPanel::__set_properties

	$self->SetTitle(_T("Boekstuk"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(352, 300)));
	$self->{dt_date}->SetMinSize($self->{dt_date}->ConvertDialogSizeToPixels(Wx::Size->new(44, -1)));
	$self->{b_date}->SetSize($self->{b_date}->GetBestSize());
	$self->{t_amount}->SetMinSize($self->{t_amount}->ConvertDialogSizeToPixels(Wx::Size->new(60, -1)));
	$self->{gr_bsr}->CreateGrid(0, 6);
	$self->{gr_bsr}->SetRowLabelSize(0);
	$self->{gr_bsr}->EnableEditing(0);
	$self->{gr_bsr}->EnableDragRowSize(0);
	$self->{gr_bsr}->SetSelectionMode(wxGridSelectRows);
	$self->{gr_bsr}->SetColLabelValue(0, _T("Nr"));
	$self->{gr_bsr}->SetColLabelValue(1, _T("Datum"));
	$self->{gr_bsr}->SetColLabelValue(2, _T("Omschrijving"));
	$self->{gr_bsr}->SetColLabelValue(3, _T("Bedrag"));
	$self->{gr_bsr}->SetColLabelValue(4, _T("BTW"));
	$self->{gr_bsr}->SetColLabelValue(5, _T("Rekening"));
	$self->{b_r_date}->SetSize($self->{b_r_date}->GetBestSize());
	$self->{c_r_btw}->SetSelection(0);
	$self->{c_r_kstomz}->SetSelection(0);
	$self->{l_amount2}->Enable(0);
	$self->{t_r_amount2}->Enable(0);

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Booking::IVPanel::BskPanel::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_pin} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_bsr}= Wx::StaticBoxSizer->new($self->{sz_bsr_staticbox}, wxHORIZONTAL);
	$self->{sizer_19} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_12} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_13} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_9} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{grid_sizer_11} = Wx::FlexGridSizer->new(6, 2, 2, 5);
	$self->{grid_sizer_12} = Wx::FlexGridSizer->new(2, 3, 0, 5);
	$self->{sizer_14} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_11} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_bsrs}= Wx::StaticBoxSizer->new($self->{sz_bsrs_staticbox}, wxVERTICAL);
	$self->{sizer_6} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_bsk}= Wx::StaticBoxSizer->new($self->{sz_bsk_staticbox}, wxHORIZONTAL);
	$self->{sizer_7} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{grid_sizer_2} = Wx::FlexGridSizer->new(6, 2, 2, 5);
	$self->{sizer_3} = Wx::FlexGridSizer->new(2, 2, 0, 5);
	$self->{sizer_2} = Wx::FlexGridSizer->new(2, 2, 0, 5);
	$self->{grid_sizer_2}->Add($self->{label_4}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{label_6}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_bsknr}, 0, wxRIGHT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_desc}, 1, wxRIGHT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{label_1}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add(2, 2, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_rel_code}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_rel_desc}, 1, wxLEFT|wxRIGHT|wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{label_5}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add(1, 1, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{dt_date}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{b_date}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->AddGrowableCol(1);
	$self->{grid_sizer_2}->Add($self->{sizer_2}, 1, wxEXPAND, 0);
	$self->{sizer_3}->Add($self->{label_2}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{label_3}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{t_amount}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{t_ref}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->AddGrowableCol(1);
	$self->{grid_sizer_2}->Add($self->{sizer_3}, 1, wxEXPAND, 0);
	$self->{grid_sizer_2}->AddGrowableCol(1);
	$self->{sz_bsk}->Add($self->{grid_sizer_2}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_bsk}->Add($self->{static_line_1}, 0, wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->{sizer_7}->Add($self->{b_apply}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{b_cancel}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{b_forward}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{b_backward}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_bsk}->Add($self->{sizer_7}, 0, wxRIGHT|wxEXPAND, 5);
	$self->{sz_main}->Add($self->{sz_bsk}, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->{sz_bsrs}->Add($self->{gr_bsr}, 1, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sizer_6}->Add($self->{b_add}, 0, wxLEFT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add($self->{b_dupl}, 0, wxLEFT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add($self->{b_change}, 0, wxLEFT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add($self->{b_remove}, 0, wxLEFT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add($self->{l_bsr_total}, 1, wxLEFT|wxTOP|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_bsrs}->Add($self->{sizer_6}, 0, wxBOTTOM|wxEXPAND, 5);
	$self->{sz_main}->Add($self->{sz_bsrs}, 1, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->{grid_sizer_11}->Add($self->{label_12}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{label_13}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{sizer_11}->Add($self->{td_r_date}, 1, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_11}->Add($self->{b_r_date}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{sizer_11}, 1, wxEXPAND, 0);
	$self->{grid_sizer_11}->Add($self->{t_r_desc}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_14}->Add($self->{l_amount1}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_14}->Add($self->{t_r_amount}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{sizer_14}, 1, wxEXPAND, 0);
	$self->{grid_sizer_12}->Add(1, 1, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_12}->Add($self->{label_14}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_12}->Add($self->{label_15}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_12}->Add($self->{c_r_btw}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_12}->Add($self->{t_r_btw}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_12}->Add($self->{c_r_kstomz}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{grid_sizer_12}, 1, wxEXPAND, 0);
	$self->{grid_sizer_11}->Add($self->{l_amount2}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{label_10}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{t_r_amount2}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->Add($self->{t_r_acct}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_11}->AddGrowableCol(1);
	$self->{sizer_13}->Add($self->{grid_sizer_11}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_13}->Add($self->{static_line_2}, 0, wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->{sizer_9}->Add($self->{b_r_accept}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_9}->Add($self->{b_r_cancel}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_9}->Add($self->{b_r_forward}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_9}->Add($self->{b_r_backward}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_13}->Add($self->{sizer_9}, 0, wxRIGHT|wxEXPAND, 5);
	$self->{sizer_12}->Add($self->{sizer_13}, 0, wxEXPAND, 0);
	$self->{sizer_19}->Add($self->{sizer_12}, 0, wxEXPAND, 0);
	$self->{sz_bsr}->Add($self->{sizer_19}, 1, wxEXPAND, 0);
	$self->{sz_main}->Add($self->{sz_bsr}, 0, wxLEFT|wxRIGHT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_pin}->Add($self->{cb_pin}, 0, wxLEFT|wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sz_pin}->Add(1, 1, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_main}->Add($self->{sz_pin}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sz_main}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();

# end wxGlade
}

sub _ISOtoWxD {
    return unless shift =~ /^(\d{4})-(\d\d)-(\d\d)$/;
    Wx::DateTime->newFromDMY($3,$2-1,$1,1,1,1,1);
}

sub init {
    my ($self, $id) = @_;
    $self->{bsk_id} = $id;
    #$self->{gr_bsr}->SetColLabelAlignment(wxALIGN_LEFT, wxALIGN_CENTER);
}

my @bsrmap;

sub refresh {
    my ($self) = @_;
    my $id = $self->{bsk_id};
    my $rr = $dbh->do("SELECT bsk_nr, bsk_desc, rel_code, rel_desc, bsk_date, bsk_amount, bsk_ref".
		      " FROM Boekstukken, Boekstukregels, Relaties".
		      " WHERE bsr_bsk_id = bsk_id".
		      " AND bsr_rel_code = rel_code".
		      " AND bsk_id = ?",
		      $id);

    $self->{t_bsknr}->SetValue($rr->[0]);
    $self->{t_desc}->SetValue($rr->[1]);
    $self->{t_rel_code}->SetValue($rr->[2]);
    $self->{t_rel_desc}->SetValue($rr->[3]);
    $self->{dt_date}->SetValue($rr->[4]);
#    $self->{dt_date}->SetValue(_ISOtoWxD($rr->[4]));
#    $self->{dt_date}->SetRange(_ISOtoWxD($dbh->adm("begin")), _ISOtoWxD($dbh->adm("end")));
    $self->{t_amount}->SetValue
      ($self->GetParent->{dbk_type} == DBKTYPE_INKOOP ? -$rr->[5] : $rr->[5]);
    $self->{t_ref}->SetValue($rr->[6]||"");

    my $sth = $dbh->sql_exec("SELECT bsr_nr, bsr_date, bsr_desc, bsr_amount, bsr_btw_id, bsr_acc_id".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?".
			     " ORDER BY bsr_nr", $self->{bsk_id});

    my $gr = $self->{gr_bsr};
    @bsrmap = ();
    my $row = 0;
    $gr->DeleteRows(0, $gr->GetNumberRows);
    my $tot = 0;

    while ( my $rr = $sth->fetch ) {
	my ($nr, $date, $desc, $amt, $btw, $acct) = @$rr;
	$nr =~ s/\s+$//;
	$amt = -$amt if $self->GetParent->{dbk_type} == DBKTYPE_VERKOOP;

	my $col = 0;
	my ($a, $b) = @{EB::Booking->norm_btw($amt, $btw)};
	$gr->AppendRows(1);
	$gr->SetCellValue($row, $col, $nr);
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $date);
	$gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $desc);
	$gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, numfmt($a));
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, numfmt($b));
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $acct . "   " . $dbh->accts->{$acct});
	$gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);

	$tot += $a;
	$row++;
	push(@bsrmap, $nr);
    }

    $self->resize_grid($gr);
    $self->{l_bsr_total}->SetLabel(__x("Totaal boekstukregels: {tot}",
				       tot => numfmt($tot)));
    if ( $state->bsr_pin ) {
	$self->{cb_pin}->SetValue(1);
    }
    if ( $self->{bsr_shown} || $self->{cb_pin}->IsChecked ) {
	$self->{sz_main}->Show(1, $self->{cb_pin}->IsChecked);
	$self->{sz_main}->Show(2, 1);
	$self->{sz_main}->Layout;
	$self->{bsr_show} = 1;
	$self->advance($self->{_curr_row} = 0);
    }
    else {
	$self->{sz_main}->Show(1, 1);
	$self->{sz_main}->Show(2, 0);
	$self->{bsr_shown} = 0;
	$self->{sz_main}->Layout;
    }

    $self->{_sel_row} = 0;
    $self->{_curr_row} = 0;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnCancel <event_handler>
sub OnCancel {
    my ($self, $event) = @_;
    $self->sizepos_save;
    warn "Event handler (OnCancel) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnApply <event_handler>
sub OnApply {
    my ($self, $event) = @_;
    $self->sizepos_save;
    warn "Event handler (OnApply) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnDClick <event_handler>
sub OnClick {
    my ($self, $event) = @_;
    $self = $self->GetParent;
    $self->{_sel_row} = $event->GetRow;
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnDClick <event_handler>
sub OnDClick {
    my ($self, $event) = @_;
    # This event is delivered at the Grid.
    $self = $self->GetParent;
    my $row = $self->{_curr_row} = $event->GetRow;
    $self->advance($row);
    return if $self->{cb_pin}->IsChecked;
    $self->{sz_main}->Show(1, 0);
    $self->{sz_main}->Show(2, 1);
    $self->{bsr_shown} = 1;
    $self->{sz_main}->Layout;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnDate <event_handler>
sub OnDate {
    my ($self, $event) = @_;

    warn "Event handler (OnDate) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnForward <event_handler>
sub OnForward {
    my ($self, $event) = @_;
    my $parent = $self->GetParent;
    $parent->advance(++$parent->{_curr_row});
    if ( !$self->{cb_pin}->IsChecked && $self->{bsr_shown} ) {
	$self->{sz_main}->Show(1, 0);
	$self->{sz_main}->Show(2, 1);
	$self->{sz_main}->Layout;
	$self->advance($self->{_curr_row} = 0);
    }
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnBackward <event_handler>
sub OnBackward {
    my ($self, $event) = @_;
    my $parent = $self->GetParent;
    $parent->advance(--$parent->{_curr_row});
    if ( !$self->{cb_pin}->IsChecked && $self->{bsr_shown} ) {
	$self->{sz_main}->Show(1, 0);
	$self->{sz_main}->Show(2, 1);
	$self->{sz_main}->Layout;
	$self->advance($self->{_curr_row} = 0);
    }
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnAdd <event_handler>
sub OnAdd {
    my ($self, $event) = @_;
    warn "Event handler (OnAdd) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnDupl <event_handler>
sub OnDupl {
    my ($self, $event) = @_;
    warn "Event handler (OnDupl) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnChange <event_handler>
sub OnChange {
    my ($self, $event) = @_;
    $self->advance($self->{_sel_row});
    return if $self->{cb_pin}->IsChecked;
    $self->{sz_main}->Show(1, 0);
    $self->{sz_main}->Show(2, 1);
    $self->{bsr_shown} = 1;
    $self->{sz_main}->Layout;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRemove <event_handler>
sub OnRemove {
    my ($self, $event) = @_;
    warn "Event handler (OnRemove) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnPin <event_handler>
sub OnPin {
    my ($self, $event) = @_;
    if ( $self->{cb_pin}->IsChecked ) {
	$self->advance($self->{_curr_row});
	$self->{sz_main}->Show(1,1);
	$self->{sz_main}->Show(2,1);
	$self->{bsr_shown} = 1;
	$self->{sz_main}->Layout;
	$state->bsr_pin(1);
    }
    else {
	$self->{sz_main}->Show(1,1);
	$self->{sz_main}->Show(2,0);
	$self->{bsr_shown} = 0;
	$self->{sz_main}->Layout;
	$state->bsr_pin(0);
    }

}

sub advance {
    my ($self, $row) = @_;
    $self->{b_r_backward}->Enable($row > 0);
    $self->{b_r_forward}->Enable($row < $self->{gr_bsr}->GetNumberRows-1);
    $self->{gr_bsr}->SelectRow($row);
    $self->_upd_bsr($self->{gr_bsr}->GetCellValue($row, 0), $self->{bsk_id});
}

sub _upd_bsr {
    my ($self, $bsr_nr, $bsk_id) = @_;
    my @v = @{$dbh->do("SELECT bsr_date, bsr_desc, bsr_amount, bsr_btw_id, bsr_acc_id, bsr_btw_class".
		       " FROM Boekstukregels".
		       " WHERE bsr_nr = ?".
		       " AND bsr_bsk_id = ?",
		       $bsr_nr, $bsk_id)};
    $self->{td_r_date}->SetValue(shift(@v));
    $self->{t_r_desc}->SetValue(shift(@v));

    $v[0] = -$v[0] if $self->GetParent->{dbk_type} == DBKTYPE_VERKOOP;
    my ($a, $b) = @{EB::Booking->norm_btw($v[0], $v[1])};
    $self->{t_r_amount}->SetValue(shift(@v));
    $self->{c_r_btw}->SetValue(shift(@v));
    $self->_show_amount($a, $b);
    $self->{t_r_acct}->SetValue(shift(@v));
    $self->{c_r_kstomz}->SetSelection
      ($v[0] & BTWKLASSE_BTW_BIT
       ? $v[0] & BTWKLASSE_KO_BIT
          ? 0 : 2
       : 1);
    $self->{sz_bsr_staticbox}->SetLabel
      (__x("Details boekstukregel {bsr}", bsr => $bsr_nr));
}

sub _show_amount {
    my ($self, $incl, $btw) = @_;
    if ( $self->{c_r_btw}->IsInclusive ) {
	$self->{l_amount1}->SetLabel(_T("Bedrag (incl.)"));
	$self->{l_amount2}->SetLabel(_T("Bedrag (excl.)"));
	$self->{t_r_amount2}->SetValue(numfmt($incl - $btw));
    }
    else {
	$self->{l_amount1}->SetLabel(_T("Bedrag (excl.)"));
	$self->{l_amount2}->SetLabel(_T("Bedrag (incl.)"));
	$self->{t_r_amount2}->SetValue(numfmt($incl));
    }
    $self->{t_r_btw}->SetValue($btw);
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRDate <event_handler>
sub OnRDate {
    my ($self, $event) = @_;
    warn "Event handler (OnRDate) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRBTW <event_handler>
sub OnRBTW {
    my ($self, $event) = @_;

    my $btw = $self->{c_r_btw}->GetValue;
    my $amt = $self->{t_r_amount}->GetValue;
    my ($a, $b) = @{EB::Booking->norm_btw($amt, $btw)};
    $self->_show_amount($a, $b);
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRKstOmz <event_handler>
sub OnRKstOmz {
    my ($self, $event) = @_;
    warn "Event handler (OnKstOmz) not implemented";
    $event->Skip;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRApply <event_handler>
sub OnRApply {
    my ($self, $event) = @_;
    return if $self->{cb_pin}->IsChecked;
    $self->{sz_main}->Show(2,0);
    $self->{sz_main}->Show(1,1);
    $self->{bsr_shown} = 0;
    $self->{sz_main}->Layout;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRCancel <event_handler>
sub OnRCancel {
    my ($self, $event) = @_;
    return if $self->{cb_pin}->IsChecked;
    $self->{sz_main}->Show(2,0);
    $self->{sz_main}->Show(1,1);
    $self->{bsr_shown} = 0;
    $self->{sz_main}->Layout;
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRForward <event_handler>
sub OnRForward {
    my ($self, $event) = @_;
    $self->advance(++$self->{_curr_row});
}

# wxGlade: EB::Wx::Booking::IVPanel::BskPanel::OnRBackward <event_handler>
sub OnRBackward {
    my ($self, $event) = @_;
    $self->advance(--$self->{_curr_row});
}

# end of class EB::Wx::Booking::IVPanel::BskPanel

1;
