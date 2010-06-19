#! perl

package main;

our $state;
our $app;
our $dbh;

package EB::Wx::Maint::Dagboeken;

use Wx qw[:everything];
use strict;
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use Wx::Grid;
use EB;
use EB::Wx::UI::BalAccInput;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Maint::Dagboeken::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{s_details_staticbox} = Wx::StaticBox->new($self, -1, _T("Details") );
	$self->{sz_grid_staticbox} = Wx::StaticBox->new($self, -1, _T("Dagboeken") );
	$self->{gr_list} = Wx::Grid->new($self, -1);
	$self->{static_line_2} = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{b_add} = Wx::Button->new($self, -1, _T("Toevoegen"));
	$self->{b_details} = Wx::Button->new($self, -1, _T("Wijzigen"));
	$self->{b_remove} = Wx::Button->new($self, -1, _T("Verwijderen"));
	$self->{label_1} = Wx::StaticText->new($self, -1, _T("Code"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_2} = Wx::StaticText->new($self, -1, _T("Omschrijving"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_3} = Wx::StaticText->new($self, -1, _T("Soort"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_code} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{t_desc} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{c_type} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, [], );
	$self->{label_4} = Wx::StaticText->new($self, -1, _T("Grootboekrekening"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_5} = Wx::StaticText->new($self, -1, _T("Debet/Credit"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_acct} = Wx::CheckBox->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{t_acct} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{c_dcsplit} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, [], );
	$self->{static_line_1} = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{b_apply} = Wx::Button->new($self, -1, _T("Toepassen"));
	$self->{b_cancel} = Wx::Button->new($self, -1, _T("Annuleren"));
	$self->{l_inuse} = Wx::StaticText->new($self, -1, _T("Sommige gegevens zijn in gebruik en\nkunnen niet meer worden gewijzigd."), wxDefaultPosition, wxDefaultSize, );
	$self->{b_close} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_add}->GetId, \&OnAdd);
	Wx::Event::EVT_BUTTON($self, $self->{b_details}->GetId, \&OnDetails);
	Wx::Event::EVT_BUTTON($self, $self->{b_remove}->GetId, \&OnRemove);
	Wx::Event::EVT_CHECKBOX($self, $self->{cb_acct}->GetId, \&OnCBAcct);
	Wx::Event::EVT_BUTTON($self, $self->{b_apply}->GetId, \&OnApply);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_close}->GetId, \&OnClose);

# end wxGlade

	Wx::Event::EVT_MENU($self, wxID_CLOSE, \&OnClose);
	Wx::Event::EVT_GRID_SELECT_CELL($self->{gr_list}, sub {});
	Wx::Event::EVT_GRID_CELL_LEFT_CLICK($self->{gr_list}, \&OnClick);
	Wx::Event::EVT_GRID_CELL_LEFT_DCLICK($self->{gr_list}, \&OnSel);
	Wx::Event::EVT_CLOSE($self, \&OnClose);
	Wx::Event::EVT_IDLE($self, \&OnIdle);
	$self->{sz_buttons}->Show(0, 0);
	$self->{sz_main}->Show(1, 0);
	$self->Layout;

	return $self;

}

sub __set_properties {
	my $self = shift;

	$self->set_properties;

# begin wxGlade: EB::Wx::Maint::Dagboeken::__set_properties

	$self->SetTitle(_T("Onderhoud Dagboeken"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(368, 316)));
	$self->{c_type}->SetSelection(0);
	$self->{c_dcsplit}->SetSelection(0);
	$self->{b_close}->SetFocus();
	$self->{b_close}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::Dagboeken::__do_layout

	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_details}= Wx::StaticBoxSizer->new($self->{s_details_staticbox}, wxHORIZONTAL);
	$self->{sizer_4} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_6} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_5} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{grid_sizer_1} = Wx::FlexGridSizer->new(3, 3, 3, 5);
	$self->{sizer_7} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_grid}= Wx::StaticBoxSizer->new($self->{sz_grid_staticbox}, wxHORIZONTAL);
	$self->{sz_dbk} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2}->Add($self->{gr_list}, 1, wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{static_line_2}, 0, wxTOP|wxEXPAND, 5);
	$self->{sizer_3}->Add($self->{b_add}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_details}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_remove}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add(1, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxTOP|wxEXPAND, 5);
	$self->{sz_dbk}->Add($self->{sizer_2}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_grid}->Add($self->{sz_dbk}, 1, wxEXPAND, 0);
	$self->{sz_main}->Add($self->{sz_grid}, 1, wxALL|wxEXPAND, 5);
	$self->{grid_sizer_1}->Add($self->{label_1}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{label_2}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{label_3}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{t_code}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{t_desc}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{c_type}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add(1, 1, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{label_4}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{label_5}, 0, wxALIGN_BOTTOM|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add(2, 2, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{cb_acct}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{t_acct}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{sizer_7}, 1, wxEXPAND, 0);
	$self->{grid_sizer_1}->Add($self->{c_dcsplit}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->AddGrowableCol(1);
	$self->{sizer_5}->Add($self->{grid_sizer_1}, 1, wxEXPAND, 0);
	$self->{sizer_4}->Add($self->{sizer_5}, 1, wxEXPAND, 0);
	$self->{sizer_4}->Add($self->{static_line_1}, 0, wxTOP|wxEXPAND, 5);
	$self->{sizer_6}->Add($self->{b_apply}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add($self->{b_cancel}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{sizer_6}->Add(1, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add($self->{sizer_6}, 0, wxTOP|wxEXPAND, 5);
	$self->{s_details}->Add($self->{sizer_4}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_main}->Add($self->{s_details}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sz_buttons}->Add($self->{l_inuse}, 0, wxLEFT|wxBOTTOM|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_buttons}->Add(20, 20, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_close}, 0, wxALL|wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 5);
	$self->{sz_main}->Add($self->{sz_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_main});
	$self->Layout();

# end wxGlade
}

sub set_properties {		# Specific
	my $self = shift;

	$self->{c_type}->Append($_) foreach grep { !/^-/ } @{DBKTYPES()};
	$self->{c_dcsplit}->Append($_) foreach qw(Samen Apart);

	$self->{t_acct}->Destroy;
	$self->{t_acct} = EB::Wx::UI::BalAccInput->new($self, -1);

	$self->{gr_list}->CreateGrid(0, 5);
	$self->{gr_list}->SetRowLabelSize(0);
	$self->{gr_list}->EnableEditing(0);
	$self->{gr_list}->EnableDragColSize(0);
	$self->{gr_list}->EnableDragRowSize(0);
	$self->{gr_list}->SetSelectionMode(wxGridSelectRows);
	$self->{gr_list}->SetColLabelValue(0, _T("Code"));
	$self->{gr_list}->SetColLabelValue(1, _T("Omschrijving"));
	$self->{gr_list}->SetColLabelValue(2, _T("Type"));
	$self->{gr_list}->SetColLabelValue(3, _T("Grootboekrekening"));
	$self->{gr_list}->SetColLabelValue(4, _T("Debet/Credit"));

}

################ Task Specific Code ################

sub get_data {
    my ($self) = @_;
    $self->{_grid_map} = [];
    my $sth = $dbh->sql_exec
      ("SELECT dbk_id, dbk_desc, dbk_type, dbk_dcsplit, dbk_acc_id".
       " FROM Dagboeken".
       " ORDER BY dbk_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	push(@{$self->{_grid_map}},
	     [@$rr,
	      defined($dbh->do
		      ("SELECT jnl_date FROM Journal".
		       " WHERE jnl_dbk_id = ? OR jnl_rel_dbk = ? LIMIT 1",
		       $rr->[0], $rr->[0])) ? 1 : 0]);
    }
}

sub fill_row {
    my ($self, $row, @values) = @_;
    my $col = 0;
    my $p = $self->{gr_list};
    $p->SetCellValue($row, $col++, $values[0]);
    $p->SetCellValue($row, $col++, $values[1]);
    $p->SetCellValue($row, $col++, DBKTYPES->[$values[2]]);
    $p->SetCellValue($row, $col++, $values[4] . "   " . $dbh->accts->{$values[4]});
    $p->SetCellValue($row, $col++, $values[3] ? "Apart" : "Samen");
}

sub show_row {
    my ($self, $row, @v) = @_;
    $self->{t_code}->SetValue(shift(@v));
    $self->{t_desc}->SetValue(shift(@v));
    $self->{c_type}->SetSelection(shift(@v)-1);
    $self->{c_dcsplit}->SetSelection(shift(@v));
    if ( defined $v[0] ) {
	$self->{t_acct}->SetValue(shift(@v));
	$self->{t_acct}->Enable(1);
	$self->{cb_acct}->SetValue(1);
    }
    else {
	$self->{t_acct}->SetValue("");
	$self->{t_acct}->Enable(0);
	$self->{cb_acct}->SetValue(0);
	shift(@v);
    }
}

sub details_inuse {
    my ($self, $row) = @_;
    $self->{$_}->Enable(!$self->is_inuse($row))
      foreach qw(t_code c_type cb_acct t_acct);
}

sub changed {
    my ($self) = @_;
    return 0 unless $self->{_details_shown};
    my $v = $self->{_grid_map}->[$self->{_curr_row}];
    return 1 if $self->{t_code}->GetValue ne $v->[0];
    return 2 if $self->{t_desc}->GetValue ne $v->[1];
    return 3 if $self->{c_type}->GetSelection != $v->[2]-1;
    return 4 if $self->{c_dcsplit}->GetSelection != 0+$v->[3];
    return 5 if $self->{t_acct}->GetValue != $v->[4];
    return 0;
}

sub new_row {
    my ($self) = @_;
    [ "", "", 1, 0, 0 ];
}

sub delete_row {
    my ($self, $code) = @_;
    $dbh->begin_work;
    eval {
	$dbh->sql_exec("DELETE FROM Dagboeken".
		       " WHERE dbk_id = ?",
		       $code);
	$dbh->commit;
	$self->refresh;
    };
    if ( $@ ) {
	$dbh->rollback;
	my $msg;
	$msg = "Fout tijdens het bijwerken van dagboek $code:\n". $@;
	$msg =~ s/\nat .*//s;
	EB::Wx::MessageDialog
	    ($self,
	     $msg, "Fout tijdens het bijwerken",
	     wxOK|wxICON_ERROR);
    }
}

sub apply {
    my ($self, $row) = @_;

    $dbh->begin_work;

    my $error;
    my @fields = qw(dbk_id dbk_desc dbk_type dbk_dcsplit dbk_acc_id);
    my $code;

    eval {
    if ( $self->is_new($row) ) {
	# New...
	if ( !($code = $self->{t_code}->GetValue)
	     || !$self->{t_desc}->GetValue
	     || ( $self->{c_type}->GetSelection + 1 != DBKTYPE_MEMORIAAL && !$self->{t_acct}->GetValue ) ) {
	    die("Niet alle verplichte gegevens zijn ingevuld\n");
	}
	$dbh->sql_insert("Dagboeken",
			 \@fields,
			 $code,
			 $self->{t_desc}->GetValue,
			 1 + $self->{c_type}->GetSelection,
			 $self->{c_dcsplit}->GetSelection,
			 $self->{t_acct}->GetValue);
	$self->{_grid_map}->[$row]->[-1] = 0;
    }
    else {
	# Modified...

	my @sets;
	my @values;
	my @ovalues = @{$self->{_grid_map}->[$row]};
	$code = $ovalues[0];
	my @nvalues = ( $self->{t_code}->GetValue,
			$self->{t_desc}->GetValue,
			$self->{c_type}->GetSelection + 1,
			$self->{c_dcsplit}->GetSelection,
			$self->{t_acct}->GetValue );

	my $i = 0;
	foreach ( @fields ) {
	    if ( $ovalues[$i] ne $nvalues[$i] ) {
		push(@sets, $fields[$i]." = ?");
		push(@values, $nvalues[$i]);
	    }
	    $i++;
	}

	$dbh->sql_exec("UPDATE Dagboeken".
		       " SET ". join(", ", @sets).
		       " WHERE dbk_id = ?",
		       @values, $code);
    }

    $dbh->commit;
    $self->hide_details;
    $self->refresh;

    };

    if ( $@ ) {
	$dbh->rollback;
	my $msg;
	if ( $dbh->dbh->state eq '23505' ) {
	    $msg = "Dagboekcode $code bestaat al\n";
	}
	else {
	    $msg = "Fout tijdens het bijwerken van dagboekcode $code:\n". $@;
	}
	$msg =~ s/\nat .*//s;
	EB::Wx::MessageDialog
	    ($self,
	     $msg, "Fout tijdens het bijwerken",
	     wxOK|wxICON_ERROR);
    }
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnCBAcct <event_handler>
sub OnCBAcct {
    my ($self, $event) = @_;
    if ( $self->{cb_acct}->IsChecked ) {
	$self->{t_acct}->Enable(1);
    }
    else {
	$self->{t_acct}->SetValue("");
	$self->{t_acct}->Enable(0);
    }
}

################ Generic Code ################

sub is_new {
    my ($self, $row) = @_;
    $self->{_grid_map}->[$row]->[-1] < 0;
}

sub is_inuse {
    my ($self, $row) = @_;
    $self->{_grid_map}->[$row]->[-1] > 0;
}

sub refresh {
    my ($self) = @_;

    $self->get_data;
    my $p = $self->{gr_list};
    $p->DeleteRows(0, $p->GetNumberRows, 1);
    $p->AppendRows(scalar(@{$self->{_grid_map}}));
    my $row = 0;
    my $inuse = 0;
    foreach ( @{$self->{_grid_map}} ) {
	$self->fill_row($row, @$_);
	$inuse ||= $self->is_inuse($row);
	$row++;
    }

    $self->set_current(0);
    $self->resize_grid($p);
    undef $self->{_details_shown};
    $self->{sz_buttons}->Show(0, $inuse);
}

sub set_current {
    my ($self, $row) = @_;
    $self->{_curr_row} = $row;
    $self->{b_remove}->Enable(!$self->is_inuse($row));
}

sub show_details {
    my ($self, $row) = @_;
    $row = $self->{_curr_row} unless defined $row;

    $self->show_row($row, @{$self->{_grid_map}->[$row]});
    $self->details_inuse($row);

    $self->{$_}->Enable(0)
      foreach qw(b_apply gr_list b_add b_details b_remove);

    $self->{sz_main}->Show(1,1);
    $self->{sz_main}->Show(2,0);
    $self->Layout;
    $self->{_details_shown} = 1;
}

sub hide_details {
    my ($self) = @_;
    $self->{$_}->Enable(1)
      foreach qw(gr_list b_add b_details);
    $self->{b_remove}->Enable(1) unless $self->is_inuse($self->{_curr_row});
    $self->{sz_main}->Show(1,0);
    $self->{sz_main}->Show(2,1);
    $self->Layout;
    $self->{_details_shown} = 0;
}

sub OnIdle {
    my ($self) = @_;
    return unless $self->{_details_shown};
    $self->{b_apply}->Enable($self->changed);
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;

    if ( $self->changed ) {
	my $r = EB::Wx::MessageDialog
	  ($self,
	   "Er zijn nog wijzigingen, deze zullen verloren gaan.\n".
	   "Venster toch sluiten?",
	   "Annuleren",
	   wxYES_NO|wxNO_DEFAULT|wxICON_ERROR);
	return unless $r == wxID_YES;
    }

    $self->sizepos_save;
    $self->Show(0);
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnAdd <event_handler>
sub OnAdd {
    my ($self, $event) = @_;
    my $p = $self->{gr_list};
    my $row = $p->GetNumberRows;
    $p->AppendRows(1);
    my $rr = $self->new_row;
    $self->fill_row($row, @$rr);
    push(@{$self->{_grid_map}}, [@$rr, -1]);
    $self->set_current($row);
    $self->show_details($row);
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnDetails <event_handler>
sub OnDetails {
    my ($self, $event) = @_;
    $self->show_details($self->{_curr_row});
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnRemove <event_handler>
sub OnRemove {
    my ($self, $event) = @_;
    my $code = $self->{_grid_map}->[$self->{_curr_row}]->[0];
    $self->delete_row($code);
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnApply <event_handler>
sub OnApply {
    my ($self, $event) = @_;
    $self->apply($self->{_curr_row});
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnCancel <event_handler>
sub OnCancel {
    my ($self, $event) = @_;
    if ( $self->changed ) {
	my $r = EB::Wx::MessageDialog
	  ($self,
	   "Er zijn nog wijzigingen, deze zullen verloren gaan.\n".
	   "Toch annuleren?",
	   "Annuleren",
	   wxYES_NO|wxNO_DEFAULT|wxICON_ERROR);
	return unless $r == wxID_YES;
    }
    $self->hide_details;
    if ( $self->{_curr_row} > 0 && $self->is_new($self->{_curr_row}) ) {
	$self->{gr_list}->DeleteRows($self->{_curr_row}, 1);
	$self->{_curr_row}--;
    }
# end wxGlade
}

sub OnClick {
    my ($self, $event) = @_;
    $self = $self->GetParent;
    my $row = $event->GetRow;
    $self->{gr_list}->SelectRow($row);
    $self->set_current($row);
    $event->Skip;
}

# wxGlade: EB::Wx::Maint::Dagboeken::OnSel <event_handler>
sub OnSel {
    my ($self, $event) = @_;
    $self = $self->GetParent;
    $self->set_current($event->GetRow);
    $self->show_details;
}

# end of class EB::Wx::Maint::Dagboeken

1;

