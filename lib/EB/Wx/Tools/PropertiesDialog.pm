#! perl

# $Id: PropertiesDialog.pm,v 1.4 2008/02/08 20:27:44 jv Exp $

package main;

our $cfg;
our $state;
our $app;
our $dbh;

package EB::Wx::Tools::PropertiesDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;
use EB;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Tools::PropertiesDialog::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{s_main_staticbox} = Wx::StaticBox->new($self, -1, _T("Administratiegegevens") );
	$self->{l_dbname} = Wx::StaticText->new($self, -1, _T("Database"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_dbname} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_boekjaar} = Wx::StaticText->new($self, -1, _T("Boekjaar"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_bky} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, [], );
	$self->{t_adm} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{l_open} = Wx::StaticText->new($self, -1, _T("Geopend"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_open} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_btw} = Wx::StaticText->new($self, -1, _T("BTW periode"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_btw} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, [_T("Geen"), _T("Jaar"), _T("Kwartaal"), _T("Maand")], );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");
	$self->{b_accept} = Wx::Button->new($self, wxID_APPLY, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_CHOICE($self, $self->{c_bky}->GetId, \&OnBkyChanged);
	Wx::Event::EVT_TEXT($self, $self->{t_adm}->GetId, \&OnAdmChanged);
	Wx::Event::EVT_CHOICE($self, $self->{c_btw}->GetId, \&OnBTWChanged);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_accept}->GetId, \&OnClose);

# end wxGlade

	$self->{_check_changed} = 1;
	Wx::Event::EVT_IDLE($self, \&OnIdle);
	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PropertiesDialog::__set_properties

	$self->SetTitle(_T("Eigenschappen"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(199, 97)));
	$self->{c_bky}->SetSelection(0);
	$self->{c_btw}->SetSelection(0);
	$self->{b_cancel}->SetFocus();
	$self->{b_accept}->Enable(0);
	$self->{b_accept}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PropertiesDialog::__do_layout

	$self->{s_outer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{s_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_main}= Wx::StaticBoxSizer->new($self->{s_main_staticbox}, wxVERTICAL);
	$self->{s_grid} = Wx::FlexGridSizer->new(5, 2, 3, 3);
	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_grid}->Add($self->{l_dbname}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_dbname}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_boekjaar}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_1}->Add($self->{c_bky}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_1}->Add(5, 1, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_1}->Add($self->{t_adm}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{sizer_1}, 0, wxEXPAND, 0);
	$self->{s_grid}->Add($self->{l_open}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_open}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_btw}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{c_btw}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->AddGrowableCol(1);
	$self->{s_main}->Add($self->{s_grid}, 0, wxALL|wxEXPAND, 3);
	$self->{s_outer}->Add($self->{s_main}, 0, wxALL|wxEXPAND, 5);
	$self->{s_outer}->Add(1, 5, 1, wxADJUST_MINSIZE, 0);
	$self->{s_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_buttons}->Add($self->{b_cancel}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{s_buttons}->Add($self->{b_accept}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{s_outer}->Add($self->{s_buttons}, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->SetSizer($self->{s_outer});
	$self->Layout();

# end wxGlade
}

my $btwmap = [ 0, 1, undef, undef, 2, undef, undef, undef, undef, undef, undef, undef, 3 ];
my $bkymap;

sub refresh {
    my ($self) = @_;
    my $t = $cfg->val(qw(database name));
    $t =~ s/^eekboek_//;
    $t .= " (" . $dbh->driverdb . ")";
    $self->{t_dbname}->SetValue($t);
    $self->{t_open}->SetValue($dbh->adm("opened"));

    my $sth = $dbh->sql_exec("SELECT bky_code, bky_name".
			     " FROM Boekjaren".
			     " WHERE bky_begin >= ( SELECT bky_end FROM Boekjaren WHERE bky_code = ?)".
			     " ORDER BY bky_begin", BKY_PREVIOUS);
    my $this = 0;
    $self->{c_bky}->Clear;
    $bkymap = [];
    while ( my $rr = $sth->fetchrow_arrayref ) {
	$this = @$bkymap if $rr->[0] eq $state->bky;
	push(@$bkymap, [ @$rr ]);
	$self->{c_bky}->Append($rr->[0]);
    }
    $self->{c_bky}->SetSelection($self->{o_bky} = $this);
    $self->{t_adm}->SetValue($self->{o_adm} = $bkymap->[$this]->[1]);

    $self->{c_btw}->SetSelection($self->{o_btw} = $btwmap->[$dbh->adm("btwperiod")]);
}

sub changed {
    my $self = shift;
    return 1 if $self->{o_bky} != $self->{c_bky}->GetSelection;
    return 1 if $self->{o_adm} ne $self->{t_adm}->GetValue;
    return 1 if $self->{o_btw} != $self->{c_btw}->GetSelection;
    return;
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnClose <event_handler>
sub OnClose {
    my ($self, $event, $cancel) = @_;
    unless ( $cancel ) {
	$dbh->begin_work;
	if ( $self->{o_bky} != $self->{c_bky}->GetSelection ) {
	    $state->set("bky", $bkymap->[$self->{c_bky}->GetSelection]->[0]);
	    $self->{o_adm} = $bkymap->[$self->{c_bky}->GetSelection]->[1];
	}
	eval {
	if ( $self->{o_adm} ne $self->{t_adm}->GetValue ) {
	    $dbh->sql_exec("UPDATE Boekjaren".
			   " SET bky_name = ?".
			   " WHERE bky_code = ?",
			   $self->{t_adm}->GetValue,
			   $bkymap->[$self->{c_bky}->GetSelection]->[0],
			  )->finish;
	}
	if ( $self->{o_btw} != $self->{c_btw}->GetSelection ) {
	    for ( my $i = 0; $i++; ) {
		next unless $btwmap->[$i] == $self->{c_btw}->GetSelection;
		$dbh->sql_exec("UPDATE Boekjaren".
			       " SET bky_btwperiod = $i".
			       " WHERE bky_code = ?",
			       $bkymap->[$self->{c_bky}->GetSelection]->[0],
			      )->finish;
		last;
	    }
	}
	};
	if ( $@ ) {
	    Wx::MessageBox($@, "Fout tijdens het bijwerken",
			   wxOK|wxICON_ERROR);
	    $dbh->rollback;
	}
	else {
	    $dbh->commit;
	    $app->{TOP}->SetTitle("EekBoek: " . ($self->{t_adm}->GetValue));
	    my $t = $state->bky . " (" . $self->{t_adm}->GetValue . ")";
	    Wx::LogMessage("Huidig boekjaar: $t");
	    $self->set_status("Boekjaar: $t");
	}
    }
    #$self->sizepos_save;
    $self->Show(0);
}

sub OnIdle {
    my ($self) = @_;
    return unless $self->{_check_changed};
    $self->{_check_changed} = 0;
    my $ch = $self->changed;
    $self->{b_accept}->Enable($ch);
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnBkyChanged <event_handler>
sub OnBkyChanged {
    my ($self, $event) = @_;
    my $rr = $dbh->do("SELECT bky_name, bky_btwperiod".
		      " FROM Boekjaren".
		      " WHERE bky_code = ?",
		      $bkymap->[$self->{c_bky}->GetSelection]->[0]);

    $self->{t_adm}->SetValue($self->{o_adm} = $rr->[0]);
    $self->{c_btw}->SetSelection($self->{o_btw} = $btwmap->[$rr->[1]]);
    $self->{_check_changed} = 1;
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnBTWChanged <event_handler>
sub OnBTWChanged {
    my ($self, $event) = @_;
    $self->{_check_changed} = 1;
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnCancel <event_handler>
sub OnCancel {
    my ($self, $event) = @_;
    $self->OnClose($event, 1);
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnAdmChanged <event_handler>
sub OnAdmChanged {
    my ($self, $event) = @_;
    $self->{_check_changed} = 1;
}

# end of class EB::Wx::Tools::PropertiesDialog

1;

