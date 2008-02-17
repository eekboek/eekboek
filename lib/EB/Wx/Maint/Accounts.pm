#! perl

# $Id: Accounts.pm,v 1.8 2008/02/17 14:11:34 jv Exp $

package main;

our $state;
our $dbh;
our $app;

package EB::Wx::Maint::Accounts;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;

use EB;
use EB::Format;

# begin wxGlade: ::dependencies
use EB::Wx::Maint::Accounts::TreeCtrl;
use EB::Wx::UI::NumericCtrl;
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Maint::Accounts::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{w_acc_frame} = Wx::SplitterWindow->new($self, -1, wxDefaultPosition, wxDefaultSize, wxSP_3D|wxSP_BORDER);
	$self->{maint_pane_outer} = Wx::Panel->new($self->{w_acc_frame}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{maint_pane} = Wx::Panel->new($self->{maint_pane_outer}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{sz_btw_staticbox} = Wx::StaticBox->new($self->{maint_pane}, -1, _T("BTW Tarief") );
	$self->{sz_saldo_staticbox} = Wx::StaticBox->new($self->{maint_pane}, -1, _T("Saldo") );
	$self->{sz_acc_staticbox} = Wx::StaticBox->new($self->{maint_pane}, -1, _T("Grootboekrekening") );
	$self->{tree_pane} = Wx::Panel->new($self->{w_acc_frame}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{acc_tree} = EB::Wx::Maint::Accounts::TreeCtrl->new($self->{tree_pane}, -1, wxDefaultPosition, wxDefaultSize, wxTR_HAS_BUTTONS|wxTR_NO_LINES|wxTR_HIDE_ROOT|wxTR_DEFAULT_STYLE|wxSUNKEN_BORDER);
	$self->{l_acc_id} = Wx::StaticText->new($self->{maint_pane}, -1, _T("Nr."), wxDefaultPosition, wxDefaultSize, );
	$self->{l_acc_desc} = Wx::StaticText->new($self->{maint_pane}, -1, _T("Omschrijving"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_acc_id} = EB::Wx::UI::NumericCtrl->new($self->{maint_pane}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{t_acc_desc} = Wx::TextCtrl->new($self->{maint_pane}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{rb_balres} = Wx::RadioBox->new($self->{maint_pane}, -1, _T("Indeling"), wxDefaultPosition, wxDefaultSize, [_T("Balans"), _T("Resultaat")], 0, wxRA_SPECIFY_ROWS);
	$self->{rb_debcrd} = Wx::RadioBox->new($self->{maint_pane}, -1, _T("Richting"), wxDefaultPosition, wxDefaultSize, [_T("Debet"), _T("Credit")], 0, wxRA_SPECIFY_ROWS);
	$self->{rb_kstomz} = Wx::RadioBox->new($self->{maint_pane}, -1, _T("Soort"), wxDefaultPosition, wxDefaultSize, [_T("Kosten"), _T("Omzet"), _T("Neutraal")], 0, wxRA_SPECIFY_ROWS);
	$self->{l_saldo_opening} = Wx::StaticText->new($self->{maint_pane}, -1, _T("Opening"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_saldo_opening} = Wx::StaticText->new($self->{maint_pane}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{l_saldo_act} = Wx::StaticText->new($self->{maint_pane}, -1, _T("Actueel"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_saldo_act} = Wx::StaticText->new($self->{maint_pane}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{b_accept} = Wx::Button->new($self->{maint_pane_outer}, wxID_APPLY, "");
	$self->{b_reset} = Wx::Button->new($self->{maint_pane_outer}, wxID_REVERT_TO_SAVED, "");
	$self->{b_cancel} = Wx::Button->new($self->{maint_pane_outer}, wxID_CANCEL, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_TEXT($self, $self->{t_acc_id}->GetId, \&OnAccIdChanged);
	Wx::Event::EVT_TEXT($self, $self->{t_acc_desc}->GetId, \&OnAccDescChanged);
	Wx::Event::EVT_RADIOBOX($self, $self->{rb_balres}->GetId, \&OnBalresClicked);
	Wx::Event::EVT_RADIOBOX($self, $self->{rb_debcrd}->GetId, \&OnDebcrdClicked);
	Wx::Event::EVT_RADIOBOX($self, $self->{rb_kstomz}->GetId, \&OnKstomzClicked);
	Wx::Event::EVT_BUTTON($self, $self->{b_accept}->GetId, \&OnAccept);
	Wx::Event::EVT_BUTTON($self, $self->{b_reset}->GetId, \&OnReset);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnClose);
	Wx::Event::EVT_SPLITTER_SASH_POS_CHANGED($self, $self->{w_acc_frame}->GetId, \&OnSashPosChanged);

# end wxGlade

	$self->{busy} = 0;

	Wx::Event::EVT_CLOSE($self, \&OnClose);
	# Wx::Event::EVT_KILL_FOCUS($self->{t_acc_id}, \&OnAccIdLosesFocus);
	Wx::Event::EVT_IDLE($self, \&OnIdle);

	my $sth = $::dbh->sql_exec("SELECT btw_id,btw_desc FROM BTWTabel ORDER BY btw_id");
	my @a;
	my $i = 0;
	my $fmt = "%2d    %s";
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    while ( $i < $rr->[0] ) {
		$a[$i] = sprintf($fmt, $i, "<< Ongebruikt >>");
		$i++;
	    }
	    $a[$rr->[0]] = sprintf($fmt, $rr->[0], $rr->[1]);
	    $i++;
	}
	$self->{ch_btw} = Wx::Choice->new($self->{maint_pane}, -1,
					  wxDefaultPosition, wxDefaultSize,
					  \@a);
	Wx::Event::EVT_CHOICE($self, $self->{ch_btw}, \&OnBtwChanged);
	$self->{sz_btw}->Add($self->{ch_btw}, 1, wxEXPAND, 0);
	$self->{sz_btw}->Layout;

	$self->{maint_pane}->Enable(0);

	return $self;

}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::Accounts::__set_properties

	$self->{rb_balres}->SetSelection(0);
	$self->{rb_debcrd}->SetSelection(0);
	$self->{rb_kstomz}->Show(0);
	$self->{rb_kstomz}->SetSelection(0);
	$self->{maint_pane}->Enable(0);
	$self->{b_accept}->Enable(0);
	$self->{b_reset}->Enable(0);
	$self->{b_cancel}->SetFocus();
	$self->{b_cancel}->SetDefault();
	$self->{w_acc_frame}->SetMinSize($self->{w_acc_frame}->ConvertDialogSizeToPixels(Wx::Size->new(338, 181)));

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::Accounts::__do_layout

	$self->{acc_frame_sizer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_accx} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_acccan} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_acc}= Wx::StaticBoxSizer->new($self->{sz_acc_staticbox}, wxVERTICAL);
	$self->{sz_saldo}= Wx::StaticBoxSizer->new($self->{sz_saldo_staticbox}, wxHORIZONTAL);
	$self->{gr_saldo} = Wx::FlexGridSizer->new(2, 2, 5, 5);
	$self->{sz_btw}= Wx::StaticBoxSizer->new($self->{sz_btw_staticbox}, wxHORIZONTAL);
	$self->{sz_properties} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_id} = Wx::FlexGridSizer->new(2, 2, 5, 5);
	$self->{sz_tree} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_tree}->Add($self->{acc_tree}, 1, wxEXPAND, 0);
	$self->{tree_pane}->SetSizer($self->{sz_tree});
	$self->{sz_id}->Add($self->{l_acc_id}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_id}->Add($self->{l_acc_desc}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_id}->Add($self->{t_acc_id}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_id}->Add($self->{t_acc_desc}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_id}->AddGrowableCol(1);
	$self->{sz_acc}->Add($self->{sz_id}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_properties}->Add($self->{rb_balres}, 1, wxRIGHT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_properties}->Add($self->{rb_debcrd}, 1, wxRIGHT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_properties}->Add($self->{rb_kstomz}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_acc}->Add($self->{sz_properties}, 0, wxTOP|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_acc}->Add($self->{sz_btw}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{gr_saldo}->Add($self->{l_saldo_opening}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{gr_saldo}->Add($self->{t_saldo_opening}, 0, wxLEFT|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{gr_saldo}->Add($self->{l_saldo_act}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{gr_saldo}->Add($self->{t_saldo_act}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{gr_saldo}->AddGrowableCol(1);
	$self->{sz_saldo}->Add($self->{gr_saldo}, 1, wxBOTTOM|wxEXPAND, 5);
	$self->{sz_acc}->Add($self->{sz_saldo}, 0, wxTOP|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{maint_pane}->SetSizer($self->{sz_acc});
	$self->{sz_accx}->Add($self->{maint_pane}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_accx}->Add(1, 5, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_acccan}->Add($self->{b_accept}, 0, wxLEFT|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_acccan}->Add($self->{b_reset}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{sz_acccan}->Add(5, 0, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_acccan}->Add($self->{b_cancel}, 0, wxRIGHT|wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_accx}->Add($self->{sz_acccan}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{maint_pane_outer}->SetSizer($self->{sz_accx});
	$self->{w_acc_frame}->SplitVertically($self->{tree_pane}, $self->{maint_pane_outer}, 350);
	$self->{acc_frame_sizer}->Add($self->{w_acc_frame}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{acc_frame_sizer});
	$self->{acc_frame_sizer}->Fit($self);
	$self->Layout();

# end wxGlade

	$self->{w_acc_frame}->SetSashPosition($state->accsash);

}

sub _nf {
    my ($v, $debcrd) = @_;
    my $t = numfmt(abs($v));
    $t = (" " x (AMTWIDTH - length($t))) . $t;
    $t . " " . (($debcrd xor ($v < 0)) ? "Credit" : ($v ? "Debet" : ""));
}

sub set_item {
    my ($self, $id, $type, $ctrl, $item) = @_;
    if ( $type == 2 ) {
	$self->set_acc($id, $ctrl, $item);
    }
    else {
	$self->set_vrd($id, $type, $ctrl, $item);
    }
}

sub set_acc {
    my ($self, $id, $ctrl, $item) = @_;

    local($self->{busy}) = 1;
    my $rr = $::dbh->do("SELECT acc_desc, acc_balres, acc_kstomz, acc_debcrd, acc_btw,".
			" acc_balance, acc_ibalance FROM Accounts".
			" WHERE acc_id = ?", $id);

    $self->{_type} = "acc";
    $self->{_ctrl} = $ctrl;
    $self->{_item} = $item;

    $self->{sz_acc}->GetStaticBox->SetLabel
      (($rr->[1] ? "Balans" : "Resultaat")."rekening");
    $self->{t_acc_id}->SetValue($self->{_id} = $id);
    $self->{t_acc_desc}->SetValue($self->{_desc} = $rr->[0]);
    $self->{rb_balres}->SetSelection(!($self->{_balres} = $rr->[1]));
    $self->{_kstomz} = $rr->[2];
    $self->{rb_kstomz}->SetSelection(defined($self->{_kstomz})
				     ? 1+($self->{_kstomz}) : 2);
    $self->{rb_debcrd}->SetSelection(!($self->{_debcrd} = $rr->[3]));
    $self->{rb_debcrd}->Show($self->{_balres});
    $self->{rb_kstomz}->Show(1);
    $self->{sz_properties}->Layout;
    $self->{ch_btw}->SetSelection($self->{_btw} = $rr->[4]);
    $self->{ch_btw}->Enable(defined $self->{_kstomz});
    $self->{t_saldo_act}->SetLabel(_nf($rr->[5], $rr->[3]));
    $self->{t_saldo_opening}->SetLabel(_nf($rr->[6], $rr->[3]));

    $self->{sz_acc}->Show($self->{sz_btw}, 1);
    $self->{sz_acc}->Show($self->{sz_saldo}, 1);
    $self->{sz_acc}->Layout;

    $rr = $dbh->do("SELECT jnl_acc_id FROM Journal".
		   " WHERE jnl_acc_id = ?".
		   " LIMIT 1", $id);
    foreach ( qw(rb_balres rb_kstomz rb_debcrd ch_btw) ) {
	$self->{$_}->Enable(!$rr->[0]);
    }
    foreach ( qw(t_acc_id) ) {
	$self->{$_}->SetEditable(!$rr->[0]); # TODO
    }

    $self->{b_accept}->Enable(0);
    $self->{b_reset}->Enable(0);
    $self->{maint_pane}->Enable(1);
    $self->{struct} = 0;

    $dbh->trace(1);
}

sub set_vrd {
    my ($self, $id, $type, $ctrl, $item) = @_;

    local($self->{busy}) = 1;
    my $rr = $::dbh->do("SELECT vdi_desc, vdi_balres, vdi_kstomz, vdi_struct".
			" FROM Verdichtingen".
			" WHERE vdi_id = ?", $id);

    $self->{_type} = "vdi";
    $self->{_ctrl} = $ctrl;
    $self->{_item} = $item;

    $self->{sz_acc}->GetStaticBox->SetLabel
      (($rr->[1] ? "Balans" : "Resultaat")."verdichting");
    $self->{t_acc_id}->SetValue($self->{_id} = $id);
    $self->{t_acc_desc}->SetValue($self->{_desc} = $rr->[0]);
    $self->{rb_balres}->SetSelection(!($self->{_balres} = $rr->[1]));
    $self->{rb_kstomz}->SetSelection(!($self->{_kstomz} = $rr->[2]));
    $self->{rb_debcrd}->Show(0);
    $self->{sz_properties}->Layout;

    $self->{sz_acc}->Show($self->{sz_btw}, 0);
    $self->{sz_acc}->Show($self->{sz_saldo}, 0);
    $self->{sz_acc}->Layout;

    $self->{b_accept}->Enable(0);
    $self->{b_reset}->Enable(0);
    $self->{maint_pane}->Enable(1);
    $self->{struct} = 0;

    $dbh->trace(1);
}

sub newentry {
    my ($self, $pid) = @_;

    if ( $self->{b_reset}->IsEnabled ) {
	Wx::Bell;
	return;
    }
    my $rr = $dbh->do("SELECT acc_struct FROM Accounts WHERE acc_id = ?", $pid);
    $pid = $rr->[0] if $rr;
    $rr = $dbh->do("SELECT vdi_balres, vdi_kstomz FROM Verdichtingen WHERE vdi_id = ?", $pid);
    unless ( $rr ) {
	Wx::Bell;
	return;
    }
    $self->{struct} = $pid;

    $self->{_type} = "acc";

    $self->{sz_acc}->GetStaticBox->SetLabel
      (($rr->[0] ? "Balans" : "Resultaat")."rekening");
    $self->{t_acc_id}->SetValue($self->{_id} = "0000");
    $self->{t_acc_desc}->SetValue($self->{_desc} = "");
    $self->{rb_balres}->SetSelection(!($self->{_balres} = $rr->[0]));
    $self->{rb_kstomz}->SetSelection(!($self->{_kstomz} = $rr->[1]));
    $self->{rb_debcrd}->SetSelection(!($self->{_debcrd} = 1));
    $self->{rb_debcrd}->Show(1);
    $self->{sz_properties}->Layout;
    $self->{ch_btw}->SetSelection($self->{_btw} = 0);
    $self->{t_saldo_act}->SetLabel("");
    $self->{t_saldo_opening}->SetLabel("");

    $self->{sz_acc}->Show($self->{sz_btw}, 1);
    $self->{sz_acc}->Show($self->{sz_saldo}, 1);
    $self->{sz_acc}->Layout;

    $self->{b_accept}->Enable(1);
    $self->{b_reset}->Enable(0);
    $self->{maint_pane}->Enable(1);

}

sub curr_id {
    my ($self) = @_;
    $self->{_id};
}

sub set_desc {
    my ($self, $desc) = @_;
    $self->{t_acc_desc}->SetValue($self->{_desc} = $desc);
}

sub changed {
    my ($self) = @_;
    $self->{struct} and return 1;
    $self->{_id} or return 0;
    $self->{t_acc_id}->GetValue or return 1;
    $self->{t_acc_id}->GetValue != $self->{_id} and return 1;
    $self->{t_acc_desc}->GetValue ne $self->{_desc} and return 1;
    $self->{rb_kstomz}->GetSelection == $self->{_kstomz} and return 1;
    $self->{_type} ne "acc" and return 0;
    $self->{rb_debcrd}->GetSelection == $self->{_debcrd} and return 1;
    $self->{ch_btw}->GetSelection != $self->{_btw} and return 1;
}

sub check_id {
    my ($self) = @_;
    my $obj = $self->{t_acc_id};
    return 1 if $obj->GetValue == $self->{_id};
    my $rr = $dbh->do("SELECT COUNT(*) FROM Journal WHERE jnl_acc_id = ?", $self->{_id});
    if ( $rr && $rr->[0] ) {
	EB::Wx::MessageDialog
	    ($self,
	     "Rekeningnummer ".
	     ($self->{_id}).
	     " is in gebruik en kan daarom niet worden gewijzigd.",
	     "In gebruik",
	     wxOK|wxICON_ERROR);
	local($self->{busy}) = 1;
	$obj->SetValue($self->{_id});
	return 0;
    }
    $rr = $dbh->do("SELECT COUNT(*) FROM Accounts WHERE acc_id = ?", $obj->GetValue);
    if ( $rr && $rr->[0] ) {
	EB::Wx::MessageDialog
	    ($self,
	     "Rekeningnummer ".
	     ($obj->GetValue).
	     " bestaat reeds.",
	     "In gebruik",
	     wxOK|wxICON_ERROR);
	local($self->{busy}) = 1;
	$obj->SetValue($self->{_id});
	return 0;
    }
    1;
}

# wxGlade: EB::Wx::Maint::Accounts::OnSashPosChanged <event_handler>
sub OnSashPosChanged {
    my ($self, $event) = @_;
    $state->set("accsash", $event->GetEventObject->GetSashPosition);
}

# wxGlade: EB::Wx::Maint::Accounts::OnAccIdChanged <event_handler>
sub OnAccIdChanged {
    my ($self, $event) = @_;
    return if $self->{busy};
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnAccIdLosesFocus <event_handler>
sub OnAccIdLosesFocus {
    my ($self, $event) = @_;
    my $obj = $event->GetEventObject;
    return unless $obj->IsModified;

    # This event is tied to t_acc_id, but we need the EB::Wx::Maint::Accounts frame.
    my $p = $self->GetParent;
    until ( exists($p->{_id}) ) { $p = $p->GetParent }

    $p->{refocus} = $self unless $p->check_id;

    my $ch = $p->changed;
    $p->{b_accept}->Enable($ch);
    $p->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnIdle <event_handler>
sub OnIdle {
    my ($self, $event) = @_;
    Wx::Window::SetFocus($self->{refocus}), undef $self->{refocus} if $self->{refocus};
}

# wxGlade: EB::Wx::Maint::Accounts::OnAccDescChanged <event_handler>
sub OnAccDescChanged {
    my ($self, $event) = @_;
    return if $self->{busy};

    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnBalresClicked <event_handler>
sub OnBalresClicked {
    my ($self, $event) = @_;
    return if $self->{rb_balres}->GetSelection != $self->{_balres};
    $self->{rb_balres}->SetSelection(!$self->{_balres});
    EB::Wx::MessageDialog
	($self,
	 "Om de balans/resultaat eigenschap te wijzigen ".
	 "dient u de rekening in het linker venster ".
	 "te slepen naar de gewenste plaats onder ".
	 ($self->{_balres} ? "Resultaat" : "Balans")."rekeningen",
	 "Niet zo",
	 wxOK|wxICON_ERROR);
}

# wxGlade: EB::Wx::Maint::Accounts::OnDebcrdClicked <event_handler>
sub OnDebcrdClicked {
    my ($self, $event) = @_;
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnKstomzClicked <event_handler>
sub OnKstomzClicked {
    my ($self, $event) = @_;
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnBtwChanged <event_handler>
sub OnBtwChanged {
    my ($self, $event) = @_;
    $self->{ch_btw}->SetSelection($self->{_btw});
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnAccept <event_handler>
sub OnAccept {
    my ($self, $event) = @_;

    return unless $self->check_id;

    my $type = $self->{_type};

    if ( $self->{struct} ) {
	my $sql = "INSERT INTO ".($type eq "acc" ? "Accounts" : "Verdichtingen").
	  " (acc_id,acc_desc,acc_balres,acc_kstomz,acc_debcrd,acc_struct,acc_btw,acc_balance,acc_ibalance)".
	    " VALUES(?,?,?,?,?,?,?,0,0)";
	my @args = ( $self->{_id} = $self->{t_acc_id}->GetValue,
		     $self->{_desc} = $self->{t_acc_desc}->GetValue,
		     $self->{_balres} = 1 - $self->{rb_balres}->GetSelection,
		     $self->{_kstomz} = 1 - $self->{rb_kstomz}->GetSelection,
		     $self->{_debcrd} = 1 - $self->{rb_debcrd}->GetSelection,
		     $self->{struct},
		     $self->{_btw} = $self->{ch_btw}->GetSelection);
	$dbh->begin_work;
	$dbh->sql_exec($sql, @args)->finish;
	$dbh->commit;
	$self->{struct} = 0;
    }
    else {
	my $sql = "UPDATE ".($type eq "acc" ? "Accounts" : "Verdichtingen")." SET";
	my @args;
	my $id = $self->curr_id;

	if ( $self->{t_acc_id}->GetValue ne $self->{_id} ) {
	    $sql .= " ${type}_id = ?,";
	    push(@args, $self->{_id} = $self->{t_acc_id}->GetValue);
	}
	if ( $self->{t_acc_desc}->GetValue ne $self->{_desc} ) {
	    $sql .= " ${type}_desc = ?,";
	    push(@args, $self->{_desc} = $self->{t_acc_desc}->GetValue);
	}
	if ( $self->{rb_kstomz}->GetSelection == $self->{_kstomz} ) {
	    $sql .= " ${type}_kstomz = ?,";
	    push(@args, $self->{_kstomz} = 1 - $self->{rb_kstomz}->GetSelection);
	}
	if ( $type eq "acc" ) {
	    if ( $self->{rb_debcrd}->GetSelection == $self->{_debcrd} ) {
		$sql .= " acc_debcrd = ?,";
		push(@args, $self->{_debcrd} = 1 - $self->{rb_debcrd}->GetSelection);
	    }
	    if ( $self->{ch_btw}->GetSelection != $self->{_btw} ) {
		$sql .= " acc_btw = ?,";
		push(@args, $self->{_btw} = $self->{ch_btw}->GetSelection);
	    }
	}

	if ( @args ) {
	    chop($sql);
	    $sql .= " WHERE ${type}_id = ?";
	    push(@args, $id);
	    $dbh->begin_work;
	    eval { $dbh->sql_exec($sql, @args)->finish };
	    if ( $@ ) {
		EB::Wx::MessageDialog
		    ($self,
		     "Fout tijdens de verwerking\n$@",
		     "Annuleren",
		     wxOK|wxICON_ERROR);
		$dbh->rollback;
	    }
	    else {
		$dbh->commit;
	    }

	    if ( $self->{_ctrl} ) {
		$self->{_ctrl}->SetItemText($self->{_item}, "$self->{_id}   $self->{_desc}");
		$self->{_ctrl}->SetPlData($self->{_item},
					  GrootboekHandler->new
					  ([$self->{_id}, $self->{_desc}, 2]));
	    }

	}
    }
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnReset <event_handler>
sub OnReset {
    my ($self, $event) = @_;

    $self->{t_acc_id}->SetValue($self->{_id});
    $self->{t_acc_desc}->SetValue($self->{_desc});
    $self->{rb_debcrd}->SetSelection(!$self->{_debcrd});
    $self->{rb_kstomz}->SetSelection(!$self->{_kstomz});
    $self->{ch_btw}->SetSelection($self->{_btw});

    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

# wxGlade: EB::Wx::Maint::Accounts::OnClose <event_handler>
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
    # Remember position and size.
    $self->sizepos_save;
    # Disappear.
    $self->Show(0);
}

# end of class EB::Wx::Maint::Accounts

1;

