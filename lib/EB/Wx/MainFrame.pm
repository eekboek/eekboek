# perl

package main;

our $state;
our $dbh;

package EB::Wx::MainFrame;

use Wx qw[:everything];
use base qw(Wx::Frame);
use base qw(EB::Wx::Window);
use strict;
use EB;

# begin wxGlade: ::dependencies
# end wxGlade

my %cmds;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::MainFrame::new

	$style = wxDEFAULT_FRAME_STYLE 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	

	# Menu Bar

	$self->{mainframe_menubar} = Wx::MenuBar->new();
	use constant MENU_GBK => Wx::NewId();
	use constant MENU_REL => Wx::NewId();
	use constant MENU_BTW => Wx::NewId();
	use constant MENU_STD => Wx::NewId();
	use constant MENU_R_PRF => Wx::NewId();
	use constant MENU_R_BAL => Wx::NewId();
	use constant MENU_R_RES => Wx::NewId();
	use constant MENU_R_GBK => Wx::NewId();
	use constant MENU_R_JNL => Wx::NewId();
	use constant MENU_R_BTW => Wx::NewId();
	use constant MENU_R_OP => Wx::NewId();
	use constant MENU_R_DEB => Wx::NewId();
	use constant MENU_R_CRD => Wx::NewId();
	use constant MENU_R_OBAL => Wx::NewId();
	my $wxglade_tmp_menu;
	$wxglade_tmp_menu = Wx::Menu->new();
	$wxglade_tmp_menu->Append(wxID_CLOSE, _T("Verberg log venster"), _T("Toon of verberg het log venster"));
	$wxglade_tmp_menu->Append(wxID_CLEAR, _T("Log venster schoonmaken"), "");
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(wxID_SAVE, _T("Exporteer..."), _T("Exporteer administratie"));
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(wxID_PROPERTIES, _T("Eigenschappen...\tAlt+Enter"), _T("Toon administratiegegevens"));
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(wxID_REFRESH, _T("Opnieuw starten\tAlt-R"), _T("Herstart (voor testen)"));
	$wxglade_tmp_menu->Append(wxID_EXIT, _T("Beëndigen\tAlt-x"), _T("Beëindig het programma"));
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("&Bestand"));
	$wxglade_tmp_menu = Wx::Menu->new();
	$wxglade_tmp_menu->Append(wxID_CUT, _T("Knip"), "");
	$wxglade_tmp_menu->Append(wxID_PASTE, _T("Plak"), "");
	$wxglade_tmp_menu->Append(wxID_COPY, _T("Kopiëer"), "");
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(wxID_PREFERENCES, _T("Instellingen..."), _T("Instellingen"));
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("&Edit"));
	$wxglade_tmp_menu = Wx::Menu->new();
	$wxglade_tmp_menu->Append(MENU_GBK, _T("Grootboekrekeningen"), _T("Onderhoud rekeningschema en grootboekrekeningen"));
	$wxglade_tmp_menu->Append(MENU_REL, _T("Relaties"), _T("Onderhoud debiteuren en crediteuren"));
	$wxglade_tmp_menu->Append(MENU_BTW, _T("BTW Tarieven"), _T("Onderhoud BTW tarieven"));
	$wxglade_tmp_menu->Append(MENU_STD, _T("Koppelingen"), _T("Onderhoud Standaardrekeningen (koppelingen)"));
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("&Onderhoud"));
	$wxglade_tmp_menu = Wx::Menu->new();
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("&Dagboeken"));
	$wxglade_tmp_menu = Wx::Menu->new();
	$wxglade_tmp_menu->Append(MENU_R_PRF, _T("Proef- en Saldibalans"), _T("Opmaken Proef- en Saldibalans"));
	$wxglade_tmp_menu->Append(MENU_R_BAL, _T("Balans"), _T("Opmaken Balans"));
	$wxglade_tmp_menu->Append(MENU_R_RES, _T("Resultaatrekening"), _T("Opmaken Resultaatrekening"));
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(MENU_R_GBK, _T("Grootboek"), _T("Opmaken Grootboekrapportage"));
	$wxglade_tmp_menu->Append(MENU_R_JNL, _T("Journaal"), _T("Opmaken Journaal"));
	$wxglade_tmp_menu->Append(MENU_R_BTW, _T("BTW aangifte"), _T("Opmaken BTW aangifte"));
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(MENU_R_OP, _T("Openstaande posten"), _T("Opmaken overzicht openstaande posten"));
	$wxglade_tmp_menu->Append(MENU_R_DEB, _T("Debiteuren"), _T("Opmaken Debiteurenoverzicht"));
	$wxglade_tmp_menu->Append(MENU_R_CRD, _T("Crediteuren"), _T("Opmaken Crediteurenoverzicht"));
	$wxglade_tmp_menu->AppendSeparator();
	$wxglade_tmp_menu->Append(MENU_R_OBAL, _T("Openingsbalans"), _T("Toon openingsbalans"));
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("Ra&pportages"));
	$wxglade_tmp_menu = Wx::Menu->new();
	$wxglade_tmp_menu->Append(wxID_HELP, _T("Documentatie\tF1"), _T("Toon de EekBoek documentatie"));
	$wxglade_tmp_menu->Append(wxID_ABOUT, _T("&Info..."), _T("Informatie"));
	$self->{mainframe_menubar}->Append($wxglade_tmp_menu, _T("&Hulp"));
	$self->SetMenuBar($self->{mainframe_menubar});
	
# Menu Bar end

	$self->{mainframe_statusbar} = $self->CreateStatusBar(0, 0);
	$self->{eb_logo} = Wx::StaticBitmap->new($self, -1, Wx::Bitmap->new("eb.jpg", wxBITMAP_TYPE_ANY), wxDefaultPosition, wxDefaultSize, wxDOUBLE_BORDER);
	$self->{pp_logo} = Wx::StaticBitmap->new($self, -1, Wx::Bitmap->new("perl_powered.png", wxBITMAP_TYPE_ANY), wxDefaultPosition, wxDefaultSize, );
	$self->{tx_log} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxTE_READONLY|wxHSCROLL);

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_MENU($self, wxID_CLOSE, \&OnLogw);
	Wx::Event::EVT_MENU($self, wxID_CLEAR, \&OnLogClean);
	Wx::Event::EVT_MENU($self, wxID_SAVE, \&OnExport);
	Wx::Event::EVT_MENU($self, wxID_PROPERTIES, \&OnProperties);
	Wx::Event::EVT_MENU($self, wxID_REFRESH, \&OnRestart);
	Wx::Event::EVT_MENU($self, wxID_EXIT, \&OnExit);
	Wx::Event::EVT_MENU($self, wxID_PREFERENCES, \&OnPreferences);
	Wx::Event::EVT_MENU($self, MENU_GBK, \&OnMGbk);
	Wx::Event::EVT_MENU($self, MENU_REL, \&OnMRel);
	Wx::Event::EVT_MENU($self, MENU_BTW, \&OnMBtw);
	Wx::Event::EVT_MENU($self, MENU_STD, \&OnMStdAcc);
	Wx::Event::EVT_MENU($self, MENU_R_PRF, \&OnRPrf);
	Wx::Event::EVT_MENU($self, MENU_R_BAL, \&OnRBal);
	Wx::Event::EVT_MENU($self, MENU_R_RES, \&OnRRes);
	Wx::Event::EVT_MENU($self, MENU_R_GBK, \&OnRGbk);
	Wx::Event::EVT_MENU($self, MENU_R_JNL, \&OnRJnl);
	Wx::Event::EVT_MENU($self, MENU_R_BTW, \&OnRBtw);
	Wx::Event::EVT_MENU($self, MENU_R_OP, \&OnROpen);
	Wx::Event::EVT_MENU($self, MENU_R_DEB, \&OnRDeb);
	Wx::Event::EVT_MENU($self, MENU_R_CRD, \&OnRCrd);
	Wx::Event::EVT_MENU($self, MENU_R_OBAL, \&OnROBal);
	Wx::Event::EVT_MENU($self, wxID_HELP, \&OnDoc);
	Wx::Event::EVT_MENU($self, wxID_ABOUT, \&OnAbout);

# end wxGlade

	$self->{OLDLOG} = Wx::Log::SetActiveTarget (Wx::LogTextCtrl->new($self->{tx_log}));
	Wx::Log::SetTimestamp("%T");
	Wx::LogMessage($EB::imsg);
	Wx::LogMessage("Administratie: " . $dbh->adm("name"));
	Wx::LogMessage("Huidig boekjaar: " . $state->bky) if $state->bky;

	$self->adapt_menus;

	use Wx::Event qw(EVT_CLOSE);

	EVT_CLOSE($self, \&OnExit);

	%cmds = ( props	 => wxID_PROPERTIES,
		  prefs	 => wxID_PREFERENCES,
		  exp    => wxID_SAVE,
		  gbk	 => MENU_GBK,
		  rel	 => MENU_REL,
		  btw	 => MENU_BTW,
		  std	 => MENU_STD,
		  rbal	 => MENU_R_BAL,
		  rres	 => MENU_R_RES,
		  rprf	 => MENU_R_PRF,
		  rgbk	 => MENU_R_GBK,
		  rjnl	 => MENU_R_JNL,
		  rbtw	 => MENU_R_BTW,
		  rdeb	 => MENU_R_DEB,
		  rcrd	 => MENU_R_CRD,
		  ropn	 => MENU_R_OP,
		  about	 => wxID_ABOUT,
	     );

	$self;
}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::MainFrame::__set_properties

	$self->SetTitle(_T("EekBoek"));
	$self->SetBackgroundColour(Wx::Colour->new(255, 255, 255));
	$self->{mainframe_statusbar}->SetStatusWidths();
	
	my( @mainframe_statusbar_fields ) = (
		
	);

	if( @mainframe_statusbar_fields ) {
		$self->{mainframe_statusbar}->SetStatusText($mainframe_statusbar_fields[$_], $_) 	
		for 0 .. $#mainframe_statusbar_fields ;
	}

# end wxGlade

	$self->{mainframe_statusbar}->SetStatusText($EB::imsg, 0);

}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::MainFrame::__do_layout

	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_4} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4}->Add(150, 20, 2, wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add($self->{eb_logo}, 0, wxALL|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 40);
	$self->{sizer_4}->Add(20, 20, 1, wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add($self->{pp_logo}, 0, wxRIGHT|wxTOP|wxBOTTOM|wxALIGN_CENTER_HORIZONTAL|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 40);
	$self->{sizer_4}->Add(150, 20, 2, wxADJUST_MINSIZE, 0);
	$self->{sz_main}->Add($self->{sizer_4}, 1, wxEXPAND, 0);
	$self->{sz_main}->Add($self->{tx_log}, 1, wxALL|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->SetSizer($self->{sz_main});
	$self->{sz_main}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub closehandler {
    my ($self) = @_;
    $self->sizepos_save;
    # Explicitly destroy the hidden (but still alive!) dialogs.
    foreach ( qw(opendialog) ) {
	next unless $self->{"d_$_"};
	$self->{"d_$_"}->Destroy;
    }
}

sub command {
    my ($self, $cmd) = @_;
    use Wx qw(wxEVT_COMMAND_MENU_SELECTED);

    foreach ( split(":", $cmd) ) {
	if ( exists($cmds{$_}) ) {
	    Wx::PostEvent($self,
			  Wx::CommandEvent->new(wxEVT_COMMAND_MENU_SELECTED, $cmds{$_}));
	}
	else {
	    Wx::LogMessage("Unknown command: $_");
	}
    }

}

sub adapt_menus {
    my $self = shift;

    $self->{mainframe_menubar}->Enable(MENU_BTW,   $dbh->does_btw);
    $self->{mainframe_menubar}->Enable(MENU_R_BTW, $dbh->does_btw);

    my $sth = $dbh->sql_exec("SELECT dbk_id,dbk_desc,dbk_type".
			     " FROM Dagboeken".
			     " ORDER BY dbk_desc");

    use Wx::Event qw(EVT_MENU);

    my $tmp = Wx::Menu->new;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc, $type) = @$rr;
	# This consumes Ids, but we do not expect to do this often.
	my $m = Wx::NewId();
	$tmp->Append($m, "$desc\tAlt-$id",
		     __x("Dagboek {dbk}", dbk => $desc)."\n");
	my $tp = qw(X IV IV BKM BKM BKM)[$type];
	my $cl = "EB::Wx::Booking::${tp}Panel";
	undef($self->{"d_dbkpanel$id"});
	EVT_MENU($self, $m,
		 sub { eval "require $cl";
		       die($@) if $@;
		       my $cfg = $state->get(lc($tp)."w");
		       $self->{"d_dbkpanel$id"} ||=
			 $cl->new($self, -1,
				  __x("Dagboek {dbk}", dbk => $desc)."\n",
				  [$cfg->{xpos}, $cfg->{ypos}],
				  [$cfg->{xwidth}, $cfg->{ywidth}]);
		       ### TODO: How to save/restore geometry?
		       $self->{"d_dbkpanel$id"}->init($id, $desc, $type);
		       $self->{"d_dbkpanel$id"}->Show(1);
		       $self->{"d_dbkpanel$id"}->SetSize([$cfg->{xwidth}, $cfg->{ywidth}]);
		   });
    }

    my $ix = $self->{mainframe_menubar}->FindMenu(_T("&Dagboeken"));
    $tmp = $self->{mainframe_menubar}->Replace
      ($ix, $tmp,
       $self->{mainframe_menubar}->GetLabelTop($ix));
    $tmp->Destroy if $tmp;
    $self->{mainframe_menubar}->Refresh;

    my $t = $::cfg->val(qw(database name));
    $t =~ s/^eekboek_//;
    $t = $dbh->adm("name");
    $self->{mainframe_statusbar}->SetStatusText(__x("Administratie: {adm}",
						    adm => $t), 0);
    $self->SetTitle(__x("EekBoek: {adm}",
			adm => $dbh->adm("name")));
}

sub DESTROY {
    my $self = shift;
    Wx::Log::SetActiveTarget($self->{OLDLOG})->Destroy;
}

################ Menu: File ################


# wxGlade: EB::Wx::MainFrame::OnExport <event_handler>
sub OnExport {
    my ($self, $event) = @_;

    my $c = $state->expdir;
    $state->expdir("") unless $c && -d $c;
    require EB::Wx::Tools::Export;
    $self->{d_export} ||= EB::Wx::Tools::Export->new
      ($self, -1,
       _T("Exporteren administratie"),
       wxDefaultPosition,
       wxDefaultSize,
       wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER,
       "",
      );
    $self->{d_export}->refresh;
    $self->{d_export}->ShowModal;
}

# wxGlade: EB::Wx::MainFrame::OnProperties <event_handler>
sub OnProperties {
    my ($self, $event) = @_;
    require EB::Wx::Tools::PropertiesDialog;
    $self->{d_prpdialog} ||= EB::Wx::Tools::PropertiesDialog->new
      ($self, -1,
       _T("Administratiegegevens"),
       wxDefaultPosition, wxDefaultSize,
      );
    #$self->{d_prpdialog}->sizepos_restore("prpw");
    $self->{d_prpdialog}->refresh;
    $self->{d_prpdialog}->ShowModal;
}

# wxGlade: EB::Wx::MainFrame::OnLogw <event_handler>
sub OnLogw {
    my ($self, $event) = @_;
    if ( $self->{tx_log}->IsShown ) {
	$self->{tx_log}->Show(0);
	$self->{mainframe_menubar}->SetLabel(wxID_CLOSE, "Toon log venster");
    }
    else {
	$self->{tx_log}->Show(1);
	$self->{mainframe_menubar}->SetLabel(wxID_CLOSE, "Verberg log venster");
    }
    $self->Layout;
}

# wxGlade: EB::Wx::MainFrame::OnLogClean <event_handler>
sub OnLogClean {
    my ($self, $event) = @_;
    $self->{tx_log}->Clear;
}

# wxGlade: EB::Wx::MainFrame::OnRestart <event_handler>
sub OnRestart {
    my ($self, $event) = @_;
    $self->closehandler(@_);
    $EB::Wx::Main::restart++;
    $self->Close(1);
}

# wxGlade: EB::Wx::MainFrame::OnExit <event_handler>
sub OnExit {
    my ($self, $event) = @_;
    $self->closehandler(@_);
    $self->Destroy;
}

################ Menu: Edit ################

# wxGlade: EB::Wx::MainFrame::OnPreferences <event_handler>
sub OnPreferences {
    my ($self, $event) = @_;
    require EB::Wx::Tools::PreferencesDialog;
    my $p = "d_mprfpanel";
    $self->{$p} ||= EB::Wx::Tools::PreferencesDialog->new
      ($self, -1,
       "Voorkeursinstellingen",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{$p}->sizepos_restore("prefw");
    $self->{$p}->refresh;
    $self->{$p}->Show(1);
}

################ Maintenance ################

# wxGlade: EB::Wx::MainFrame::OnMGbk <event_handler>
sub OnMGbk {
    my ($self, $event) = @_;
    require EB::Wx::Maint::Accounts;
    my $p = "d_maccpanel";
    $self->{$p} ||= EB::Wx::Maint::Accounts->new
      ($self, -1,
       "Raadplegen Grootboekrekeningen",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{$p}->sizepos_restore("accw");
    $self->{$p}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnMRel <event_handler>
sub OnMRel {
    my ($self, $event) = @_;
    require EB::Wx::Maint::Relaties;
    my $p = "d_mrelpanel";
    $self->{$p} ||= EB::Wx::Maint::Relaties->new
      ($self, -1,
       "Onderhoud Relaties",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{$p}->sizepos_restore("relw");
    $self->{$p}->refresh;
    $self->{$p}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnMBtw <event_handler>
sub OnMBtw {
    my ($self, $event) = @_;
    require EB::Wx::Maint::BTWTarieven;
    my $p = "d_mbtwpanel";
    $self->{$p} ||= EB::Wx::Maint::BTWTarieven->new
      ($self, -1,
       "Onderhoud BTW instellingen",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{$p}->sizepos_restore("btww");
    $self->{$p}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnMStdAcc <event_handler>
sub OnMStdAcc {
    my ($self, $event) = @_;
    require EB::Wx::Maint::StdAccounts;
    my $p = "d_mstdpanel";
    $self->{$p} ||= EB::Wx::Maint::StdAccounts->new
      ($self, -1,
       "Onderhoud Koppelingen",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{$p}->sizepos_restore("stdw");
    $self->{$p}->Show(1);
}

################ Menu: Reports ################

# wxGlade: EB::Wx::MainFrame::OnRPrf <event_handler>
sub OnRPrf {
    my ($self, $event) = @_;
    require EB::Wx::Report::BalResProof;
    $self->{d_rprfpanel} ||= EB::Wx::Report::BalResProof->new
      ($self, -1,
       "Proef & Saldibalans",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rprfpanel}->sizepos_restore("rprfw");
    $self->{d_rprfpanel}->init("prf");
    $self->{d_rprfpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRBal <event_handler>
sub OnRBal {
    my ($self, $event) = @_;
    require EB::Wx::Report::BalResProof;
    $self->{d_rbalpanel} ||= EB::Wx::Report::BalResProof->new
      ($self, -1,
       "Balans",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rbalpanel}->sizepos_restore("rbalw");
    $self->{d_rbalpanel}->init("bal");
    $self->{d_rbalpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRRes <event_handler>
sub OnRRes {
    my ($self, $event) = @_;
    require EB::Wx::Report::BalResProof;
    $self->{d_rrespanel} ||= EB::Wx::Report::BalResProof->new
      ($self, -1,
       "Resultaat",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rrespanel}->sizepos_restore("rresw");
    $self->{d_rrespanel}->init("res");
    $self->{d_rrespanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRGbk <event_handler>
sub OnRGbk {
    my ($self, $event) = @_;
    require EB::Wx::Report::Grootboek;
    $self->{d_rgbkpanel} ||= EB::Wx::Report::Grootboek->new
      ($self, -1,
       "Grootboek",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rgbkpanel}->sizepos_restore("rgbkw");
    $self->{d_rgbkpanel}->init("gbk");
    $self->{d_rgbkpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRJnl <event_handler>
sub OnRJnl {
    my ($self, $event) = @_;
    require EB::Wx::Report::Journaal;
    $self->{d_rjnlpanel} ||= EB::Wx::Report::Journaal->new
      ($self, -1,
       "Journaal",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rjnlpanel}->sizepos_restore("rjnlw");
    $self->{d_rjnlpanel}->init("jnl");
    $self->{d_rjnlpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRBtw <event_handler>
sub OnRBtw {
    my ($self, $event) = @_;
    require EB::Wx::Report::BTWAangifte;
    $self->{d_rbtwpanel} ||= EB::Wx::Report::BTWAangifte->new
      ($self, -1,
       "BTW aangifte",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rbtwpanel}->sizepos_restore("rbtww");
    $self->{d_rbtwpanel}->init("btw");
    $self->{d_rbtwpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnROpen <event_handler>
sub OnROpen {
    my ($self, $event) = @_;
    require EB::Wx::Report::Openstaand;
    $self->{d_ropnpanel} ||= EB::Wx::Report::Openstaand->new
      ($self, -1,
       "Openstaande posten",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_ropnpanel}->sizepos_restore("ropnw");
    $self->{d_ropnpanel}->init("opn");
    $self->{d_ropnpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRDeb <event_handler>
sub OnRDeb {
    my ($self, $event) = @_;
    require EB::Wx::Report::DebCrd;
    $self->{d_rdebpanel} ||= EB::Wx::Report::DebCrd->new
      ($self, -1,
       "Debiteuren",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rdebpanel}->sizepos_restore("rdebw");
    $self->{d_rdebpanel}->init("deb");
    $self->{d_rdebpanel}->Show(1);
}

# wxGlade: EB::Wx::MainFrame::OnRCrd <event_handler>
sub OnRCrd {
    my ($self, $event) = @_;
    require EB::Wx::Report::DebCrd;
    $self->{d_rcrdpanel} ||= EB::Wx::Report::DebCrd->new
      ($self, -1,
       "Crediteuren",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_rcrdpanel}->sizepos_restore("rcrdw");
    $self->{d_rcrdpanel}->init("crd");
    $self->{d_rcrdpanel}->Show(1);
}


# wxGlade: EB::Wx::MainFrame::OnROBal <event_handler>
sub OnROBal {
    my ($self, $event) = @_;
    require EB::Wx::Report::BalResProof;
    $self->{d_robalpanel} ||= EB::Wx::Report::BalResProof->new
      ($self, -1,
       "Openingsbalans",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_robalpanel}->sizepos_restore("robalw");
    $self->{d_robalpanel}->init("obal");
    $self->{d_robalpanel}->Show(1);
}

################ Menu: Info ################

# wxGlade: EB::Wx::MainFrame::OnDoc <event_handler>
sub OnDoc {
    my ($self, $event) = @_;
    Wx::LaunchDefaultBrowser("http:www.eekboek.nl/docs/index.html");
}

# wxGlade: EB::Wx::MainFrame::OnAbout <event_handler>
sub OnAbout {
    my ($self, $event) = @_;

    require EB::Wx::Tools::AboutDialog;
    $self->{d_about} ||= EB::Wx::Tools::AboutDialog->new
      ($self, -1,
       "Info ...",
       wxDefaultPosition, wxDefaultSize,
      );
    $self->{d_about}->init();
    $self->{d_about}->refresh();
    $self->{d_about}->ShowModal;
}

################ End of Menus ################

# end of class EB::Wx::MainFrame

1;

