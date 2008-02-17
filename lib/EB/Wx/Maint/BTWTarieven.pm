#! perl

# $Id: BTWTarieven.pm,v 1.11 2008/02/17 14:11:58 jv Exp $

package main;

our $state;
our $app;
our $dbh;

package EB::Wx::Maint::BTWTarieven;

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

# begin wxGlade: EB::Wx::Maint::BTWTarieven::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sz_btwpanel_staticbox} = Wx::StaticBox->new($self, -1, _T("BTWTarieven") );
	$self->{panel} = Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{l_inuse} = Wx::StaticText->new($self, -1, _T("Sommige gegevens zijn in gebruik en\nkunnen niet meer worden gewijzigd."), wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

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

    my $sth;
    my $tv = BTWTARIEVEN;
    $tv = [ @$tv ];

    require EB::Wx::UI::GridPanel::TextCtrl;
    require EB::Wx::UI::GridPanel::AmtInput;
    require EB::Wx::UI::GridPanel::Choice;
    require EB::Wx::UI::GridPanel::RemoveButton;

    $self->{panel}->create
      ([ _T("Code")		  => EB::Wx::UI::GridPanel::TextCtrl::,
	 _T("Omschrijving")	  => EB::Wx::UI::GridPanel::TextCtrl::,
	 _T("Perc.")	          => EB::Wx::UI::GridPanel::AmtInput::,
	 _T("Tariefgroep")        => [ EB::Wx::UI::GridPanel::Choice::, $tv ],
	 _T("Incl./Excl.")        => [ EB::Wx::UI::GridPanel::Choice::,
				       [ qw(Exclusief Inclusief) ] ],
	 ""		          => EB::Wx::UI::GridPanel::RemoveButton::,
       ], 0, 0 );
    $self->{panel}->addgrowablecol(1);

    my $p = $self->{panel};

    $sth = $dbh->sql_exec("SELECT btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl".
			  " FROM BTWTabel".
			  " ORDER BY btw_id");

    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($code, $desc, $perc, $tg, $incl) = @$rr;
	$p->append($code, $desc, $perc, $tg, $incl, 0, $code);
	if ( $code == 0
	     || defined $dbh->do("SELECT bsr_btw_id FROM Boekstukregels".
				 " WHERE bsr_btw_id = ? LIMIT 1",
				 $code) ) {
	    $p->enable( 0, 1, 0, 0, 0);
	    $self->{l_inuse}->Show(1);
	}
    }
}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Maint::BTWTarieven::__set_properties

	$self->SetTitle(_T("Onderhoud BTWTarieven"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(368, 166)));
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

# begin wxGlade: EB::Wx::Maint::BTWTarieven::__do_layout

	$self->{sz_outer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_btwpanel}= Wx::StaticBoxSizer->new($self->{sz_btwpanel_staticbox}, wxHORIZONTAL);
	$self->{sz_btw} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_btw}->Add($self->{panel}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_btwpanel}->Add($self->{sz_btw}, 1, wxEXPAND, 0);
	$self->{sz_outer}->Add($self->{sz_btwpanel}, 1, wxALL|wxEXPAND, 5);
	$self->{sz_buttons}->Add($self->{l_inuse}, 0, wxLEFT|wxBOTTOM|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_buttons}->Add(20, 20, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_buttons}->Add($self->{b_cancel}, 0, wxALL|wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 5);
	$self->{sz_outer}->Add($self->{sz_buttons}, 0, wxALL|wxEXPAND, 5);
	$self->SetSizer($self->{sz_outer});
	$self->Layout();

# end wxGlade
}

# wxGlade: EB::Wx::Maint::BTWTarieven::OnClose <event_handler>
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

# wxGlade: EB::Wx::Maint::BTWTarieven::OnApply <pseudo event_handler>
sub OnApply {
    my ($self, $data) = @_;

    #  ret -> [ [ <action>, <new contents>, <user data> ], ...]
    #
    #  action: 0 -> new row
    #         -1 -> deleted row
    #       else -> changed row, 1 bit per changed column

    $dbh->begin_work;
    my $error;
    my @fields = qw(btw_id btw_desc btw_perc btw_tariefgroep btw_incl);
    foreach my $op ( @$data ) {
	my $code = shift(@$op);
	my $orig = $op->[scalar(@fields) + 1];
	eval {

	if ( $code == 0 ) {
	    # New.
	    if ( !$op->[0] || !$op->[1]) {
		     die("Niet alle verplichte gegevens zijn ingevuld\n");
	    }
	    $dbh->sql_insert("BTWTabel", \@fields, @$op[0..4]);
	    #### TODO: New inserted entries lack the 'orig' data,
	    #### so they cannot be changed or modified...
	}
	elsif ( $code < 0 || $code == 4294967295 ) {
	    # Deleted.
	    unless ( defined $orig ) {
		EB::Wx::MessageDialog
		    ($self,
		     "Deze nieuw toegevoegde entry kan nog niet worden verwijderd.",
		     "Fout tijdens het bijwerken",
		     wxOK|wxICON_ERROR);
		next;
	    }
	    $dbh->sql_exec("DELETE FROM BTWTabel".
			   " WHERE btw_id = ?",
			   $orig);
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
	    my @sets;
	    my @values;
	    my $i = 0;
	    foreach ( @fields ) {
		if ( $code & 1 ) {
		    push(@sets, "$_ = ?");
		    push(@values, $op->[$i]);
		}
		$code >>= 1;
		$i++;
	    }
	    $dbh->sql_exec("UPDATE BTWTabel".
			   " SET ". join(", ", @sets).
			   " WHERE btw_id = ?",
			   @values, $orig);
	}

	};
	if ( $@ ) {
	    $error++;
	    $orig ||= $op->[0];
	    my $msg;
	    if ( $dbh->dbh->state eq '23505' ) {
		$msg = "Dagboekcode $orig bestaat al\n";
	    }
	    else {
		$msg = "Fout tijdens het bijwerken van btwcode $orig:\n". $@;
	    }
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

# end of class EB::Wx::Maint::BTWTarieven

1;

