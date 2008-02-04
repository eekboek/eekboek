#! perl

# $Id: BTWTarieven.pm,v 1.8 2008/02/04 23:25:49 jv Exp $

package main;

our $dbh;
our $state;
our $app;

package EB::Wx::Maint::BTWTarieven;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;

use EB;
use EB::Format;

# begin wxGlade: ::dependencies
use Wx::Grid;
use EB::Wx::UI::NumericCtrl;
use EB::Wx::UI::AmountCtrl;
# end wxGlade

my $bm_edit_remove;
my $bm_edit_trash;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

	$bm_edit_trash  ||= Wx::Bitmap->new("edittrash.png", wxBITMAP_TYPE_ANY);
	$bm_edit_remove ||= Wx::Bitmap->new("edit_remove.png", wxBITMAP_TYPE_ANY);

# begin wxGlade: EB::Wx::Maint::BTWTarieven::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_btw_staticbox} = Wx::StaticBox->new($self, -1, _T("BTW Tariefcodes") );
	$self->{btwpanel} = Wx::ScrolledWindow->new($self, -1, wxDefaultPosition, wxDefaultSize, wxTAB_TRAVERSAL);
	$self->{bl_code} = Wx::StaticText->new($self->{btwpanel}, -1, _T("Code"), wxDefaultPosition, wxDefaultSize, );
	$self->{bl_desc} = Wx::StaticText->new($self->{btwpanel}, -1, _T("Omschrijving"), wxDefaultPosition, wxDefaultSize, );
	$self->{bl_perc} = Wx::StaticText->new($self->{btwpanel}, -1, _T("Perc"), wxDefaultPosition, wxDefaultSize, );
	$self->{bl_group} = Wx::StaticText->new($self->{btwpanel}, -1, _T("Groep"), wxDefaultPosition, wxDefaultSize, );
	$self->{bl_incl} = Wx::StaticText->new($self->{btwpanel}, -1, _T("In/Excl"), wxDefaultPosition, wxDefaultSize, );
	$self->{bl_del} = Wx::StaticText->new($self->{btwpanel}, -1, _T("Verw"), wxDefaultPosition, wxDefaultSize, );
	$self->{bw_apply} = Wx::Button->new($self, wxID_APPLY, "");
	$self->{bw_new} = Wx::Button->new($self, wxID_ADD, "");
	$self->{bw_reset} = Wx::Button->new($self, wxID_REVERT_TO_SAVED, "");
	$self->{l_inuse} = Wx::StaticText->new($self, -1, _T("Sommige gegevens zijn in gebruik en\nkunnen niet meer worden gewijzigd."), wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{bw_apply}->GetId, \&OnApply);
	Wx::Event::EVT_BUTTON($self, $self->{bw_new}->GetId, \&OnNew);
	Wx::Event::EVT_BUTTON($self, $self->{bw_reset}->GetId, \&OnReset);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnClose);

# end wxGlade

	Wx::Event::EVT_IDLE($self, \&OnIdle);

	$self->refresh;
	my $ch = $self->changed;
	$self->{bw_apply}->Enable($ch);
	$self->{bw_reset}->Enable($ch);

	return $self;

}

sub OnIdle {
    my ($self) = @_;
    return unless $self->{_check_changed};
    $self->{_check_changed} = 0;
    my $ch = $self->changed;
    $self->{bw_apply}->Enable($ch);
    $self->{bw_reset}->Enable($ch);
}

sub refresh {
    my ($self) = @_;
    local($self->{busy}) = 1;

    foreach ( @{$self->{_btw}}) {
	my ($id, $desc, $perc, $groep, $incl) = @$_;
	$self->{"tx_btw_xs_${id}"} = $desc eq "\0";
	$self->{"tx_btw_xx_${id}"}->SetBitmapLabel($bm_edit_trash);
	$self->{"tx_btw_id_${id}"}->SetValue($id);
	$self->{"tx_btw_dc_${id}"}->SetValue($desc);
	$self->{"tx_btw_pc_${id}"}->SetValue($perc);
	$self->{"tx_btw_tg_${id}"}->SetSelection($groep);
	$self->{"tx_btw_in_${id}"}->SetSelection(1-$incl);
    }

    ###### DIT DEUGT NIET -- DOET COMMITS!
    goto &OnApply;
}

sub changed {
    my ($self) = @_;
    return 0 if $self->{busy};

    my $ch = 0;
    foreach ( @{$self->{_btw}} ) {
	my ($id, $desc, $perc, $groep, $incl) = @$_;
	$ch++, last if $self->{"tx_btw_xs_${id}"};
	$ch++, last if $self->{"tx_btw_id_${id}"}->GetValue != $id;
	$ch++, last if $self->{"tx_btw_dc_${id}"}->GetValue ne $desc;
	$ch++, last if $self->{"tx_btw_pc_${id}"}->GetValue ne $perc;
	$ch++, last if $self->{"tx_btw_tg_${id}"}->GetSelection != $groep;
	$ch++, last if $self->{"tx_btw_in_${id}"}->GetSelection == $incl;
    }
    # ...
    return $ch;
}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::BTWTarieven::__set_properties

	$self->SetTitle(_T("BTW Tarieven"));
	$self->{btwpanel}->SetScrollRate(10, 10);
	$self->{b_cancel}->SetFocus();
	$self->{b_cancel}->SetDefault();

# end wxGlade

	$self->{busy} = 0;

	$self->{_open} = $dbh->adm_open;

	$self->{_btw} = [];
	my $sth = $dbh->sql_exec("SELECT btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl".
				 " FROM BTWTabel".
				 " ORDER BY btw_id");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    $rr->[-1] ||= 0;
	    push(@{$self->{_btw}}, [@$rr]);
	    my ($id, $desc, $perc, $tg, $incl) = @$rr;
	    $self->{"tx_btw_id_$id"} = EB::Wx::UI::NumericCtrl->new($self->{btwpanel}, -1, "", wxDefaultPosition, wxDefaultSize, );
	    $self->{"tx_btw_dc_$id"} = Wx::TextCtrl->new($self->{btwpanel}, -1, "", wxDefaultPosition, wxDefaultSize, );
	    $self->{"tx_btw_pc_$id"} = EB::Wx::UI::AmountCtrl->new($self->{btwpanel}, -1, "", wxDefaultPosition, wxDefaultSize, );
	    $self->{"tx_btw_tg_$id"} = Wx::Choice->new($self->{btwpanel}, -1, wxDefaultPosition, wxDefaultSize, BTWTYPES);
	    $self->{"tx_btw_in_$id"} = Wx::Choice->new($self->{btwpanel}, -1, wxDefaultPosition, wxDefaultSize, [qw(Incl Excl)]);
	    $self->{"tx_btw_xx_$id"} = Wx::BitmapButton->new($self->{btwpanel}, -1, $bm_edit_trash);
	    $self->{"tx_btw_xs_$id"} = 0;

	}
	$sth->finish;
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::BTWTarieven::__do_layout

	$self->{sz_btwpanel} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_btwmain} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_btw}= Wx::StaticBoxSizer->new($self->{sz_btw_staticbox}, wxVERTICAL);
	$self->{sz_btw_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_btws} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_g_btw} = Wx::FlexGridSizer->new(1, 6, 0, 0);
	$self->{sz_g_btw}->Add($self->{bl_code}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->Add($self->{bl_desc}, 1, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->Add($self->{bl_perc}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->Add($self->{bl_group}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->Add($self->{bl_incl}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->Add($self->{bl_del}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{sz_g_btw}->AddGrowableCol(1);
	$self->{sz_btws}->Add($self->{sz_g_btw}, 0, wxALL|wxEXPAND, 5);
	$self->{btwpanel}->SetSizer($self->{sz_btws});
	$self->{sz_btw}->Add($self->{btwpanel}, 1, wxEXPAND, 0);
	$self->{sz_btw_buttons}->Add($self->{bw_apply}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_btw_buttons}->Add($self->{bw_new}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{sz_btw_buttons}->Add(5, 1, 1, wxADJUST_MINSIZE, 0);
	$self->{sz_btw_buttons}->Add($self->{bw_reset}, 0, wxADJUST_MINSIZE, 0);
	$self->{sz_btw}->Add($self->{sz_btw_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->{sz_btwmain}->Add($self->{sz_btw}, 2, wxEXPAND, 0);
	$self->{sz_btwmain}->Add(20, 5, 0, wxEXPAND, 0);
	$self->{sz_buttons}->Add($self->{l_inuse}, 0, wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_cancel}, 0, wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 5);
	$self->{sz_btwmain}->Add($self->{sz_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->{sz_btwpanel}->Add($self->{sz_btwmain}, 1, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_btwpanel});
	$self->{sz_btwpanel}->Fit($self);
	$self->Layout();

# end wxGlade

	my $any = 0;
	foreach ( @{$self->{_btw}} ) {
	    my ($id, $desc, $perc, $groep, $incl) = @$_;
	    $self->{"sz_btw_$id"} = Wx::BoxSizer->new(wxHORIZONTAL);
	    $self->{"tx_btw_id_$id"}->SetValue($id);
	    $self->{"tx_btw_dc_$id"}->SetValue($desc);
	    $self->{"tx_btw_pc_$id"}->SetValue($perc);
	    $self->{"tx_btw_tg_$id"}->SetSelection($groep);
	    #$self->{"tx_btw_in_$id"}->SetValue($incl);
	    $self->{"tx_btw_in_$id"}->SetSelection(1 - ($incl||0));

	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_id_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_dc_$id"}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_pc_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_tg_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_in_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	    $self->{"sz_g_btw"}->Add($self->{"tx_btw_xx_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);

	    if ( $id == 0 ||
		$self->{_open} && $dbh->do("SELECT COUNT(*) FROM Boekstukregels WHERE bsr_btw_id = ?", $id)->[0] ) {
		$self->{"tx_btw_${_}_$id"}->Enable(0) for qw(id pc tg in xx);
		$any++;
	    }

	    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_id_$id"}->GetId, sub { $_[0]->OnIdChanged($_[1], $id) });
	    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_dc_$id"}->GetId, sub { $_[0]->OnDcChanged($_[1], $id) });
	    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_pc_$id"}->GetId, sub { $_[0]->OnPcChanged($_[1], $id) });
	    Wx::Event::EVT_CHOICE($self, $self->{"tx_btw_tg_$id"}->GetId, sub { $_[0]->OnTgChanged($_[1], $id) });
	    Wx::Event::EVT_CHOICE($self, $self->{"tx_btw_in_$id"}->GetId, sub { $_[0]->OnInChanged($_[1], $id) });
	    Wx::Event::EVT_BUTTON($self, $self->{"tx_btw_xx_$id"}->GetId, sub { $_[0]->OnRemove($_[1], $id) });
	}

	$self->{l_inuse}->Show($any);
	$self->Layout();

}

sub OnIdChanged {
    my ($self, $event, $id) = @_;
    goto &OnRemove if $self->{"tx_btw_xs_$id"};
    $self->{_check_changed}++;
}

sub OnInChanged {
    my ($self, $event, $id) = @_;
    $self->flip_button($id) if $self->{"tx_btw_xs_$id"};
    $self->{_check_changed}++;
}

sub OnTgChanged {
    my ($self, $event, $id) = @_;
    $self->flip_button($id) if $self->{"tx_btw_xs_$id"};
    $self->{_check_changed}++;
}

sub OnDcChanged {
    my ($self, $event, $id) = @_;
    $self->flip_button($id) if $self->{"tx_btw_xs_$id"};
    $self->{_check_changed}++;
}

sub OnPcChanged {
    my ($self, $event, $id) = @_;
    $self->flip_button($id) if $self->{"tx_btw_xs_$id"};
    $self->{_check_changed}++;
}

sub OnRemove {
    my ($self, $event, $id) = @_;
    $self->flip_button($id);
}

sub flip_button {
    my ($self, $id, $state) = @_;
    $state = !$self->{"tx_btw_xs_$id"} unless defined $state;
    $self->{_check_changed}++ unless $self->{"tx_btw_xs_$id"} == $state;
    $self->{"tx_btw_xs_$id"} = $state;
    $self->{"tx_btw_xx_$id"}->SetBitmapLabel($state ? $bm_edit_remove : $bm_edit_trash);
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnNew <event_handler>
sub OnNew {
    my ($self, $event) = @_;
    my ($id, $desc, $perc, $group, $in) = (0, "\0", 0, 0, 1);
    foreach ( @{$self->{_btw}} ) {
	$id = $_->[0] if $_->[0] > $id;
    }
    $id++;
    push(@{$self->{_btw}}, [$id, $desc, $group, $in]);
    $self->{"tx_btw_id_$id"} = EB::Wx::UI::NumericCtrl->new($self->{btwpanel}, -1, $id, wxDefaultPosition, wxDefaultSize, );
    $self->{"tx_btw_dc_$id"} = Wx::TextCtrl->new($self->{btwpanel}, -1, $desc, wxDefaultPosition, wxDefaultSize, );
    $self->{"tx_btw_pc_$id"} = EB::Wx::UI::AmountCtrl->new($self->{btwpanel}, -1, $perc, wxDefaultPosition, wxDefaultSize, );
    $self->{"tx_btw_tg_$id"} = Wx::Choice->new($self->{btwpanel}, -1, wxDefaultPosition, wxDefaultSize, BTWTYPES);
    $self->{"tx_btw_tg_$id"}->SetSelection($group);
    $self->{"tx_btw_in_$id"} = Wx::Choice->new($self->{btwpanel}, -1, wxDefaultPosition, wxDefaultSize, [qw(Incl Excl)]);
    $self->{"tx_btw_in_$id"}->SetSelection(1-$in);
    $self->{"tx_btw_xx_$id"} = Wx::BitmapButton->new($self->{btwpanel}, -1, $bm_edit_remove);
    $self->{"tx_btw_xs_$id"} = 1;

    $self->{sz_g_btw}->Add($self->{"tx_btw_id_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->{sz_g_btw}->Add($self->{"tx_btw_dc_$id"}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->{sz_g_btw}->Add($self->{"tx_btw_pc_$id"}, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->{sz_g_btw}->Add($self->{"tx_btw_tg_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->{sz_g_btw}->Add($self->{"tx_btw_in_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->{sz_g_btw}->Add($self->{"tx_btw_xx_$id"}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
    $self->Layout;

    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_id_$id"}->GetId, sub { $_[0]->OnIdChanged($_[1], $id) });
    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_dc_$id"}->GetId, sub { $_[0]->OnDcChanged($_[1], $id) });
    Wx::Event::EVT_TEXT($self, $self->{"tx_btw_pc_$id"}->GetId, sub { $_[0]->OnPcChanged($_[1], $id) });
    Wx::Event::EVT_CHOICE($self, $self->{"tx_btw_tg_$id"}->GetId, sub { $_[0]->OnTgChanged($_[1], $id) });
    Wx::Event::EVT_CHOICE($self, $self->{"tx_btw_in_$id"}->GetId, sub { $_[0]->OnInChanged($_[1], $id) });
    Wx::Event::EVT_BUTTON($self, $self->{"tx_btw_xx_$id"}->GetId, sub { $_[0]->OnRemove($_[1], $id) });
    $self->{_check_changed}++;
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnApply <event_handler>
sub OnApply {
    my ($self, $event) = @_;
    $dbh->begin_work;
    eval { $self->on_apply };
    if ( $@ ) {
	$dbh->rollback;
	Wx::MessageBox("Dat ging niet helemaal lekker.\n".$@,
		       "Oeps",
		       wxOK|wxICON_ERROR);
    }
    else {
	$dbh->commit;
    }
    $self->{_check_changed}++;
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnApply <event_handler>
sub on_apply {
    my ($self, $event) = @_;
    my $i = 0;
    my @btw = @{$self->{_btw}};
    foreach my $r ( @btw ) {
	my ($id, $desc, $perc, $group, $in) = @$r;
	my $t;
	my $newid = $id;
	if ( ($t = $self->{"tx_btw_id_$id"}->GetValue) != $id ) {
	    $newid = $t;
	}
	if ( ($t = $self->{"tx_btw_pc_$id"}->GetValue) != $perc ) {
	    $perc = $t;
	}
	if ( ($t = $self->{"tx_btw_tg_$id"}->GetSelection) != $group ) {
	    $group = $t;
	}
	if ( ($t = $self->{"tx_btw_in_$id"}->GetSelection) == $in ) {
	    $t = 1 - $t;
	    $in = $t;
	}
	if ( ($t = $self->{"tx_btw_dc_$id"}->GetValue) ne $desc ) {
	    if ( $desc eq "\0" ) {
		$dbh->sql_exec("INSERT INTO BTWTabel".
			       " (btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl)".
			       " VALUES(?,?,?,?,?)", $newid, $t, $perc, $group, $in)->finish;
	    }
	    $desc = $t;
	}
	if ( $self->{"tx_btw_xs_$id"}
	     || ($desc eq "\0" && $self->{"tx_btw_dc_$id"}->GetValue eq "") ) {
	    $dbh->sql_exec("DELETE FROM BTWTabel WHERE btw_id = ?", $id)->finish unless $desc eq "\0";;
	    for ( 1..6 ) {
		my $item = $self->{sz_g_btw}->GetItem(6*($i+1));
		$self->{sz_g_btw}->Remove(6*($i+1));
		$item->GetWindow->Destroy;
	    }
	    $self->Layout;
	    splice(@{$self->{_btw}}, $i, 1);
	    $i--;
	    next;
	}
	if ( $newid != $id ) {
	    $dbh->sql_exec("UPDATE BTWTabel SET btw_id = ? WHERE btw_id = ?", $newid, $id)->finish
	      unless $desc eq "\0";
	    for ( qw(id dc pc tg in xx xs) ) {
		$self->{"tx_btw_${_}_$newid"} = $self->{"tx_btw_${_}_$id"};
		delete($self->{"tx_btw_${_}_$id"});
	    }
	    $id = $newid;
	}
	@{$r}[0..4] = ($id, $desc, $perc, $group, $in);
	$i++;
    }
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnReset <event_handler>
sub OnReset {
    my ($self, $event) = @_;

    $self->refresh;
    $self->{_check_changed}++;
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    if ( $self->changed ) {
	my $r = Wx::MessageBox("Er zijn nog wijzigingen, deze zullen verloren gaan.\n".
			       "Venster toch sluiten?",
			       "Annuleren",
			       wxYES_NO|wxNO_DEFAULT|wxICON_ERROR);
	return unless $r == wxYES;
	$self->OnReset($event);
    }
    # Remember position and size.
    $self->sizepos_save;
    # Disappear.
    $self->Show(0);

}

# end of class EB::Wx::Maint::BTWTarieven

1;

