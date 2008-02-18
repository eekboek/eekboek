#! perl

# $Id: Relaties.pm,v 1.12 2008/02/18 10:20:41 jv Exp $

package main;

our $state;
our $app;
our $dbh;

package EB::Wx::Maint::Relaties;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;

use EB;

# begin wxGlade: ::dependencies
use EB::Wx::UI::GridPanel;
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Maint::Relaties::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_relpanel_staticbox} = Wx::StaticBox->new($self, -1, _T("Relaties") );
	$self->{l_sel} = Wx::StaticText->new($self, -1, _T("Selecteer:"), wxDefaultPosition, wxDefaultSize, );
	$self->{ch_deb} = Wx::CheckBox->new($self, -1, _T("Debiteuren"), wxDefaultPosition, wxDefaultSize, );
	$self->{ch_crd} = Wx::CheckBox->new($self, -1, _T("Crediteuren"), wxDefaultPosition, wxDefaultSize, );
	$self->{panel} = Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{l_inuse} = Wx::StaticText->new($self, -1, _T("Sommige gegevens zijn in gebruik en\nkunnen niet meer worden gewijzigd."), wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_CHECKBOX($self, $self->{ch_deb}->GetId, \&OnDeb);
	Wx::Event::EVT_CHECKBOX($self, $self->{ch_crd}->GetId, \&OnCrd);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnClose);

# end wxGlade

	Wx::Event::EVT_CLOSE($self, \&OnClose);
	$self->{l_inuse}->Show(0);

	$self->fill_grid;

	$self->{panel}->registerapplycb(sub { $self->OnApply(@_) });

	return $self;

}

my @dbkmap;

sub refresh {
    goto &fill_grid;
}

sub fill_grid {
    my ($self) = @_;

    my $deb = $self->{ch_deb}->GetValue;
    my $crd = $self->{ch_crd}->GetValue;
    my $asel = "";
    my $dsel = "";
    my $dbks;
    my $sth;
    my $allsel = " WHERE dbk_type = " . DBKTYPE_INKOOP .
      " OR dbk_type = " . DBKTYPE_VERKOOP;
    if ( $deb && !$crd ) {
	$asel = " WHERE rel_debcrd";
	$dsel = " WHERE dbk_type = " . DBKTYPE_VERKOOP;
    }
    elsif ( !$deb && $crd ) {
	$asel = " WHERE NOT rel_debcrd";
	$dsel = " WHERE dbk_type = " . DBKTYPE_INKOOP;
    }
    else {
	$dsel = " WHERE dbk_type = " . DBKTYPE_INKOOP .
	  " OR dbk_type = " . DBKTYPE_VERKOOP;
    }

    $sth = $dbh->sql_exec("SELECT dbk_desc, dbk_id FROM Dagboeken".
			 $allsel);
    @dbkmap = ();
    foreach ( @{$sth->fetchall_arrayref} ) {
	push(@$dbks, $_->[0]);
	push(@dbkmap, $_->[1]);
    }
    my %dbkmap;
    my $i = 0;
    foreach ( @dbkmap ) {
	$dbkmap{$_} = $i++;
    }

    $sth = $dbh->sql_exec("SELECT rel_code, rel_desc, rel_debcrd, rel_btw_status, rel_ledger, rel_acc_id".
			  " FROM Relaties".
			  $asel.
			  " ORDER BY rel_code");
    my $rows = $sth->rows;
    unless ( $rows ) {
	$rows = $dbh->do("SELECT COUNT(*) FROM Relaties".$asel);
    }

    # This can be slow, show progressbar.
    # (Constructing the GridPanel is slow, not the AccInput widgets.)
    my $prog = Wx::ProgressDialog->new
      ("Voortgang", "Laden relatie-informatie",
       $rows, $self, wxPD_AUTO_HIDE|wxPD_APP_MODAL);


    require EB::Wx::UI::GridPanel::TextCtrl;
    require EB::Wx::UI::GridPanel::AccInput;
    require EB::Wx::UI::GridPanel::Choice;
    require EB::Wx::UI::GridPanel::RemoveButton;

    $self->{panel}->create
      ([ _T("Code")		  => EB::Wx::UI::GridPanel::TextCtrl::,
	 _T("Omschrijving")	  => EB::Wx::UI::GridPanel::TextCtrl::,
	 _T("Grootboekrekening")  => EB::Wx::UI::GridPanel::AccInput::,
	 _T("Dagboek")	          => [ EB::Wx::UI::GridPanel::Choice::, $dbks ],
	 $dbh->does_btw ? ( _T("BTW")
			    => [ EB::Wx::UI::GridPanel::Choice::,
		 	         [ qw(Normaal Verlegd Intra Extra) ] ] ) : (),
	 ""		          => EB::Wx::UI::GridPanel::RemoveButton::,
       ], 0, 0, $rows );
    $self->{panel}->addgrowablecol(1);
    $self->{panel}->addgrowablecol(2);

    my $p = $self->{panel};

    my $row;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	$row = 0 if $row >= $rows;
	$prog->Update(++$row);
	my ($code, $desc, $debcrd, $btw, $ledger, $acct) = @$rr;
	my $inuse = defined $dbh->do("SELECT bsr_nr FROM Boekstukregels".
				     " WHERE bsr_rel_code = ? AND bsr_dbk_id = ? LIMIT 1",
				     $code, $ledger);
	$p->append($code, $desc, $acct, $dbkmap{$ledger}, $btw, 0, $code, $ledger);
	if ( $inuse ) {
	    $p->enable( 0, 1, 0, 0,
			$dbh->does_btw ? 1 : (), 0);
	    $self->{l_inuse}->Show(1);
	}
    }
    $prog->Destroy;
}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::Relaties::__set_properties

	$self->SetTitle(_T("Onderhoud Relaties"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(369, 167)));
	$self->{ch_deb}->SetValue(1);
	$self->{ch_crd}->SetValue(1);
	$self->{b_cancel}->SetFocus();
	$self->{b_cancel}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

	# Due to a small inconvenience in wxGlade 0.3 we have to
	# replace the vanilla panel with out custom panel.
	$self->{panel}->Destroy;
	$self->{panel} = new EB::Wx::UI::GridPanel($self, -1, wxDefaultPosition, wxDefaultSize, 0,);

# begin wxGlade: EB::Wx::Maint::Relaties::__do_layout

	$self->{sz_outer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_relpanel}= Wx::StaticBoxSizer->new($self->{sz_relpanel_staticbox}, wxHORIZONTAL);
	$self->{sz_rel} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_debcrd} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_debcrd}->Add($self->{l_sel}, 0, wxRIGHT|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_debcrd}->Add($self->{ch_deb}, 0, wxRIGHT|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_debcrd}->Add($self->{ch_crd}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sz_debcrd}->Add(1, 1, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_rel}->Add($self->{sz_debcrd}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sz_rel}->Add($self->{panel}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_relpanel}->Add($self->{sz_rel}, 1, wxEXPAND, 0);
	$self->{sz_outer}->Add($self->{sz_relpanel}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_buttons}->Add($self->{l_inuse}, 0, wxLEFT|wxBOTTOM|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_buttons}->Add(20, 20, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_cancel}, 0, wxALL|wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 5);
	$self->{sz_outer}->Add($self->{sz_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_outer});
	$self->Layout();

# end wxGlade
}

# wxGlade: EB::Wx::Maint::Relaties::OnDeb <event_handler>
sub OnDeb {
    my ($self, $event) = @_;

    # If only Deb is selected, and Deb gets deselected, the only
    # logical action is to implicitly select Crd.

    unless ( $self->{ch_deb}->GetValue || $self->{ch_crd}->GetValue ) {
	$self->{ch_crd}->SetValue(1);
    }
    $self->fill_grid;
}

# wxGlade: EB::Wx::Maint::Relaties::OnCrd <event_handler>
sub OnCrd {
    my ($self, $event) = @_;

    # See comment at OnDeb.

    unless ( $self->{ch_deb}->GetValue || $self->{ch_crd}->GetValue ) {
	$self->{ch_deb}->SetValue(1);
    }
    $self->fill_grid;
}

# wxGlade: EB::Wx::Maint::Relaties::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;

    if ( $self->{panel}->changed ) {
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

# wxGlade: EB::Wx::Maint::Relaties::OnApply <pseudo event_handler>
sub OnApply {
    my ($self, $data) = @_;

    #  ret -> [ [ <action>, <new contents>, <user data> ], ...]
    #
    #  action: 0 -> new row
    #         -1 -> deleted row
    #       else -> changed row, 1 bit per changed column

    $dbh->begin_work;
    my $error;
    foreach my $op ( @$data ) {
	my ($code, $key, $desc, $acct, $dbk, $btw, $del, $orig, $ledger) = @$op;
	eval {
	$dbk = $dbkmap[$dbk];
	if ( $code == 0 ) {
	    # New.
	    if ( !$op->[1] || !$op->[2] || !$op->[3] || !$op->[4] ) {
		     die("Niet alle verplichte gegevens zijn ingevuld\n");
	    }
	    my $debcrd = 0+($dbh->lookup($dbk, qw(Dagboeken dbk_id dbk_type)) == DBKTYPE_VERKOOP);
	    $dbh->sql_insert("Relaties",
			     [qw(rel_code rel_desc rel_debcrd rel_btw_status rel_ledger rel_acc_id)],
			     $key, $desc, $debcrd, $btw, $dbk, $acct);
	}
	elsif ( $code < 0 ) {
	    # Deleted.
	    unless ( defined $orig ) {
		EB::Wx::MessageDialog
		    ($self,
		     "Deze nieuw toegevoegde entry kan nog niet worden verwijderd.",
		     "Fout tijdens het bijwerken",
		     wxOK|wxICON_ERROR);
		next;
	    }
	    $dbh->sql_exec("DELETE FROM Relaties".
			   " WHERE rel_code = ? and rel_ledger = ?",
			   $orig, $ledger);
	}
	else {
	    # Modified.
	    unless ( defined $orig ) {
		EB::Wx::MessageDialog
		    ($self,
		     "Deze nieuw toegevoegde entry kan nog niet worden gewijzigd.",
		     "Fout tijdens het bijwerken",
		     wxOK|wxICON_ERROR);
		next;
	    }
	    my @fields = qw(rel_code rel_desc rel_acc_id rel_ledger rel_btw_status);
	    my @sets;
	    my @values;
	    my $i = 1;
	    foreach ( @fields ) {
		if ( $code & 1 ) {
		    push(@sets, "$_ = ?");
		    if ( $i == 4 ) {
			push(@values, $dbk);
			push(@sets, "rel_debcrd = ?");
			push(@values,
			     0+($dbh->lookup($dbk,
					     qw(Dagboeken dbk_id dbk_type)) == DBKTYPE_VERKOOP));
		    }
		    else {
			push(@values, $op->[$i]);
		    }
		}
		$code >>= 1;
		$i++;
	    }
	    $dbh->sql_exec("UPDATE Relaties".
			   " SET ". join(", ", @sets).
			   " WHERE rel_code = ? AND rel_ledger = ?",
			   @values, $orig, $ledger);
	}
	};
	if ( $@ ) {
	    $error++;
	    $orig ||= $key;
	    my $msg;
	    if ( $dbh->dbh->state eq '23505' ) {
		$msg = "Relatiecode $orig bestaat al in dit dagboek\n";
	    }
	    else {
		$msg = "Fout tijdens het bijwerken van $orig:\n". $@;
	    }
	    $msg =~ s/\nat .*//s;
	    EB::Wx::MessageDialog
		($self,
		 $msg, "Fout tijdens het bijwerken",
		 wxOK|wxICON_ERROR);
	}
    }

    if ( $error ) {
	$dbh->rollback;
	return;
    }
    $dbh->commit;
    return 1;
}

# end of class EB::Wx::Maint::Relaties

1;

