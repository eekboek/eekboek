#! perl

# $Id: BKMPanel.pm,v 1.8 2008/02/20 14:02:53 jv Exp $

package main;

our $state;
our $dbh;
our $app;

package EB::Wx::Booking::BKMPanel;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;
use EB;
use EB::Format;

# begin wxGlade: ::dependencies
use Wx::Grid;
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Booking::BKMPanel::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_staticbox} = Wx::StaticBox->new($self, -1, _T("Dagboek") );
	$self->{gr_main} = Wx::Grid->new($self, -1);
	$self->{b_close} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_close}->GetId, \&OnClose);

# end wxGlade

	Wx::Event::EVT_GRID_CELL_LEFT_DCLICK($self->{gr_main}, \&OnDClick);

	$self->SetTitle($title);
	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Booking::BKMPanel::__set_properties

	$self->SetTitle(_T("Bank/Kas/Memoriaal Boeking"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(300, 168)));
	$self->{gr_main}->CreateGrid(0, 4);
	$self->{gr_main}->SetRowLabelSize(3);
	$self->{gr_main}->SetColLabelSize(22);
	$self->{gr_main}->EnableEditing(0);
	$self->{gr_main}->EnableDragRowSize(0);
	$self->{gr_main}->SetSelectionMode(wxGridSelectRows);
	$self->{gr_main}->SetColLabelValue(0, _T("Nr"));
	$self->{gr_main}->SetColLabelValue(1, _T("Datum"));
	$self->{gr_main}->SetColLabelValue(2, _T("Omschrijving"));
	$self->{gr_main}->SetColLabelValue(3, _T("Bedrag"));
	$self->{b_close}->SetFocus();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Booking::BKMPanel::__do_layout

	$self->{sz_outer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz}= Wx::StaticBoxSizer->new($self->{sz_staticbox}, wxHORIZONTAL);
	$self->{sz}->Add($self->{gr_main}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_main}->Add($self->{sz}, 1, wxEXPAND, 0);
	$self->{sz_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_close}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_main}->Add($self->{sz_buttons}, 0, wxTOP|wxEXPAND, 5);
	$self->{sz_outer}->Add($self->{sz_main}, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_outer});
	$self->Layout();

# end wxGlade
}

sub init {
    my ($self, $id, $desc, $type) = @_;
    $self->SetTitle(__x("Dagboek: {dbk}", dbk => $desc));
    $self->{dbk_id} = $id;
    $self->{dbk_desc} = $desc;
    $self->{dbk_type} = $type;
    $self->refresh;
}

sub refresh {
    my ($self) = @_;

    my $sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc,".
			     " bsk_date, bsk_amount".
			     " From Boekstukken".
			     " WHERE bsk_dbk_id = ?".
			     " ORDER BY bsk_date, bsk_id",
			     $self->{dbk_id});

    my $gr = $self->{gr_main};
    $gr->DeleteRows(0, $gr->GetNumberRows);

    my $row = 0;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($bsk_id, $bsk_nr, $bsk_desc, $bsk_date, $bsk_amount) = @$rr;
	$bsk_nr =~ s/\s+$//;

	my $col = 0;
	$gr->AppendRows(1);
	$gr->SetCellValue($row, $col, $bsk_nr);
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $bsk_date);
	$gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $bsk_desc);
	$gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, numfmt($bsk_amount));
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$row++;
    }

    $self->{_curr_row} = 0;
    $self->resize_grid($self->{gr_main});
}

# wxGlade: EB::Wx::Booking::BKMPanel::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    # Remember position and size.
    $self->sizepos_save;
    # Disappear.
    $self->Show(0);
}

# wxGlade: EB::Wx::Booking::BKMPanel::OnDClick <event_handler>
sub OnDClick {
    my ($self, $event) = @_;
    my $row = $event->GetRow;
    warn("row = $row\n");
}

# end of class EB::Wx::Booking::BKMPanel

1;

