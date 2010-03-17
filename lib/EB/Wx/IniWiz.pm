#! perl --			-*- coding: utf-8 -*-

use utf8;

package main;

use strict;
use warnings;

use EekBoek;
use EB;
use EB::Tools::MiniAdm;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );

our $app;
our $cfg;

our @ebz;

my @configs = ( qw( schema.dat mutaties.eb relaties.eb opening.eb ) );

package EB::Wx::IniWiz;

use Wx qw[:everything];
use base qw(Wx::Frame);
use EB;
use File::Basename;

my @db_drivers;
my @adm_dirs;
my @adm_names;

my $runeb;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::IniWiz::new

	$style = wxDEFAULT_FRAME_STYLE 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{p_dummy} = Wx::Panel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p05} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p04} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p03} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p02} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p01} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{wiz_p00} = Wx::WizardPanel->new($self->{p_dummy}, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{sizer_5_staticbox} = Wx::StaticBox->new($self->{wiz_p01}, -1, _T("Administratie") );
	$self->{sizer_8_staticbox} = Wx::StaticBox->new($self->{wiz_p02}, -1, _T("BTW") );
	$self->{sizer_6_staticbox} = Wx::StaticBox->new($self->{wiz_p03}, -1, _T("Dagboeken") );
	$self->{sizer_4_staticbox} = Wx::StaticBox->new($self->{wiz_p04}, -1, _T("Database") );
	$self->{sizer_2_staticbox} = Wx::StaticBox->new($self->{wiz_p05}, -1, _T("Bevestiging") );
	$self->{sizer_12_staticbox} = Wx::StaticBox->new($self->{wiz_p00}, -1, _T("Welkom bij EekBoek") );
	$self->{t_main} = Wx::TextCtrl->new($self->{p_dummy}, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_MULTILINE|wxTE_READONLY);
	$self->{ch_runeb} = Wx::CheckBox->new($self->{p_dummy}, -1, _T("EekBoek opstarten"), wxDefaultPosition, wxDefaultSize, );
	$self->{b_ok} = Wx::Button->new($self->{p_dummy}, wxID_OK, "");
	$self->{label_7} = Wx::StaticText->new($self->{wiz_p00}, -1, _T("Dit programma kan u helpen bij het initiëel opzetten van een eenvoudige administratie."), wxDefaultPosition, wxDefaultSize, );
	$self->{label_3} = Wx::StaticText->new($self->{wiz_p01}, -1, _T("Naam"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_adm_name} = Wx::TextCtrl->new($self->{wiz_p01}, -1, _T("Mijn eerste EekBoek"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_10} = Wx::StaticText->new($self->{wiz_p01}, -1, _T("Code"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_adm_code} = Wx::TextCtrl->new($self->{wiz_p01}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{label_4} = Wx::StaticText->new($self->{wiz_p01}, -1, _T("Begindatum"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_6} = Wx::StaticText->new($self->{wiz_p01}, -1, _T("01-01-"), wxDefaultPosition, wxDefaultSize, );
	$self->{sp_adm_begin} = Wx::SpinCtrl->new($self->{wiz_p01}, -1, "", wxDefaultPosition, wxDefaultSize, wxSP_ARROW_KEYS|wxTE_AUTO_URL, 0, 100, );
	$self->{label_9} = Wx::StaticText->new($self->{wiz_p01}, -1, _T("Sjabloon"), wxDefaultPosition, wxDefaultSize, );
	$self->{ch_template} = Wx::Choice->new($self->{wiz_p01}, -1, wxDefaultPosition, wxDefaultSize, [_T("Lege administratie")], );
	$self->{cb_btw} = Wx::CheckBox->new($self->{wiz_p02}, -1, _T("BTW toepassen op deze administratie"), wxDefaultPosition, wxDefaultSize, );
	$self->{l_btw_period} = Wx::StaticText->new($self->{wiz_p02}, -1, _T("Aangifteperiode"), wxDefaultPosition, wxDefaultSize, );
	$self->{ch_btw_period} = Wx::Choice->new($self->{wiz_p02}, -1, wxDefaultPosition, wxDefaultSize, [_T("Maand"), _T("Kwartaal"), _T("Jaar")], );
	$self->{cb_debiteuren} = Wx::CheckBox->new($self->{wiz_p03}, -1, _T("Verkoop"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_crediteuren} = Wx::CheckBox->new($self->{wiz_p03}, -1, _T("Inkoop"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_kas} = Wx::CheckBox->new($self->{wiz_p03}, -1, _T("Kas"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_bank} = Wx::CheckBox->new($self->{wiz_p03}, -1, _T("Bank"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_1} = Wx::StaticText->new($self->{wiz_p04}, -1, _T("Database naam"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_db_name} = Wx::TextCtrl->new($self->{wiz_p04}, -1, "", wxDefaultPosition, wxDefaultSize, );
	$self->{label_2} = Wx::StaticText->new($self->{wiz_p04}, -1, _T("Database type"), wxDefaultPosition, wxDefaultSize, );
	$self->{ch_db_driver} = Wx::Choice->new($self->{wiz_p04}, -1, wxDefaultPosition, wxDefaultSize, [_T("PostgreSQL"), _T("SQLite")], );
	$self->{label_5} = Wx::StaticText->new($self->{wiz_p05}, -1, _T("Druk op 'Voltooien' om de volgende bestanden aan te maken:"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_config} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Configuratiebestand"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_schema} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Rekeningschema"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_relaties} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Relaties (debiteuren en crediteuren)"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_opening} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Openingsgegevens"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_mutaties} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Mutaties (boekingen)"), wxDefaultPosition, wxDefaultSize, );
	$self->{cb_cr_database} = Wx::CheckBox->new($self->{wiz_p05}, -1, _T("Database"), wxDefaultPosition, wxDefaultSize, );
	$self->{label_8} = Wx::StaticText->new($self->{wiz_p05}, -1, _T("Let op! Eventuele bestaande bestanden worden overschreven!"), wxDefaultPosition, wxDefaultSize, );

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_ok}->GetId, \&OnOk);

# end wxGlade

	# Set defaults for code and db name.
	OnSelectAdmName( $self->{wiz} );

	my $prev;
	for ( my $i = 0; ; $i++ ) {
	    my $page = sprintf("wiz_p%02d", $i);
	    last unless exists $self->{$page};
	    $self->{sz_main}->Detach($self->{$page});
	    Wx::WizardPageSimple::Chain( $self->{$prev}, $self->{$page} )
		if $prev;
	    $prev = $page;
	}

	@ebz = glob( libfile("schema/*.ebz") );

	my $i = 0;
	foreach my $ebz ( @ebz ) {
	    require Archive::Zip;
	    my $zip = Archive::Zip->new();
	    next unless $zip->read($ebz) == ::AZ_OK;
	    my $desc = $zip->zipfileComment;
	    if ( $desc =~ /omschrijving:\s+(.*)/i ) {
		$desc = $1;
	    }
	    elsif ( $desc =~ /export van (.*) aangemaakt door eekboek/i ) {
		$desc = $1;
	    }
	    else {
		$desc = $1 if $ebz =~ m/([^\\\/]+)\.ebz$/i;
	    }
	    $self->{ch_template}->Append($desc);
	    $i++;
	    if ( $ebz =~ /\/sample(db)?\.ebz$/ ) {
		$self->{ch_template}->SetSelection($i);
		OnSelectTemplate( $self->{wiz} );
	    }
	}
	unshift (@ebz, undef );	# skeleton

	# Enumerate DB drivers.
	my $drivers = find_db_drivers();
	$self->{ch_db_driver}->Delete(0) while $self->{ch_db_driver}->GetCount;
	foreach ( sort keys %$drivers ) {
	    push( @db_drivers, $_ );
	    $self->{ch_db_driver}->Append( $drivers->{$_} );
	    $self->{ch_db_driver}->SetSelection(@db_drivers-1) if $_ eq "sqlite";
	}

	#### WARNING: Hard-wired reference to wiz_p04.
#	$self->{dc_dbpath} = Wx::DirPickerCtrl->new($self->{wiz_p04}, -1, "", _T("Kies een folder"), wxDefaultPosition, wxDefaultSize, 2 );
#	$self->{grid_db}->Replace( $self->{l_placeholder_dbpath}, $self->{dc_dbpath}, 1 );
#	$self->{l_placeholder_dbpath}->Destroy;
#	$self->{dc_dbpath}->SetToolTipString(_T("Folder waar databases worden opgeslagen (niet voor alle database typen)"));
#	$self->{dc_dbpath}->SetPath(_T("-- Huidige directory --"));

	Wx::Event::EVT_WIZARD_PAGE_CHANGING($self, $self->{wiz}->GetId, \&OnPageChanging);
	Wx::Event::EVT_WIZARD_FINISHED($self, $self->{wiz}->GetId, \&OnWizardFinished );
	Wx::Event::EVT_WIZARD_CANCEL($self, $self->{wiz}->GetId, \&OnWizardCancel );
	Wx::Event::EVT_CHECKBOX($self->{wiz}, $self->{cb_btw}->GetId, \&OnToggleBTW );
	Wx::Event::EVT_CHECKBOX($self->{wiz}, $self->{cb_cr_schema}->GetId, \&OnToggleCreate );
	Wx::Event::EVT_CHECKBOX($self->{wiz}, $self->{cb_cr_opening}->GetId, \&OnToggleCreate );
	Wx::Event::EVT_CHECKBOX($self->{wiz}, $self->{cb_cr_relaties}->GetId, \&OnToggleCreate );
	Wx::Event::EVT_CHECKBOX($self->{wiz}, $self->{cb_cr_mutaties}->GetId, \&OnToggleCreate );
	Wx::Event::EVT_CHOICE($self->{wiz}, $self->{ch_template}->GetId, \&OnSelectTemplate );
	Wx::Event::EVT_TEXT($self->{wiz}, $self->{t_adm_name}->GetId, \&OnSelectAdmName );
	Wx::Event::EVT_TEXT($self->{wiz}, $self->{t_adm_code}->GetId, \&OnSelectAdmCode );
	Wx::Event::EVT_SPINCTRL($self->{wiz}, $self->{sp_adm_begin}->GetId, \&OnSelectAdmName );


	$self->{wiz}->SetPageSize([600,-1]);

	my $icon = Wx::Icon->new();
	$icon->CopyFromBitmap(Wx::Bitmap->new("eb.jpg", wxBITMAP_TYPE_ANY));
	$self->SetIcon($icon);
	$self->{wiz}->SetIcon($icon);
	$self->SetSize([450,300]);

	return $self;
}

sub runwiz {
    my ( $self, $opts ) = @_;
    $self->{wiz}->RunWizard( $self->{wiz_p00} );
    $self->{wiz}->Destroy;
}

sub getadm {			# STATIC
    my ( $pkg, $opts ) = @_;
    chdir($opts->{admdir});
    my %h;
    $h{$_} = 1 foreach glob( "*/" . $cfg->std_config );
    $h{$_} = 1 foreach glob( "*/" . $cfg->std_config_alt );
    my @files = keys(%h);
    @adm_names = ();
    foreach ( sort @files ) {
	push( @adm_dirs, dirname($_) );
	my $desc = $adm_dirs[-1];
	if ( open( my $fd, '<:utf8', $adm_dirs[-1]."/opening.eb" ) ) {
	    while ( <$fd> ) {
		next unless /adm_naam\s+"(.+)"/;
		$desc = $1;
		last;
	    }
	    close($fd);
	}
	push( @adm_names, $desc);
    }

    my $ret = wxID_NEW;
    if ( @adm_dirs ) {
	require EB::Wx::IniWiz::OpenDialog;
	my $d = EB::Wx::IniWiz::OpenDialog->new( undef, -1,
						 _T("Kies"),
						 wxDefaultPosition, wxDefaultSize, );
	$d->init( \@adm_names );
	if ( ($ret = $d->ShowModal) == wxID_OK ) {
	    chdir( $adm_dirs[ $d->GetSelection ] ) || die("chdir");
	}
	$d->Destroy;
    }
    return $ret;

}

sub __set_properties {
	my $self = shift;

	my $year = 1900 + (localtime(time))[5];
	$self->{sp_adm_begin}->SetRange( $year-100, $year+100 );
	$self->{sp_adm_begin}->SetValue( $year );

# begin wxGlade: EB::Wx::IniWiz::__set_properties

	$self->SetTitle(_T("EekBoek MiniAdm Setup"));
	$self->{ch_runeb}->SetValue(1);
	$self->{b_ok}->Enable(0);
	$self->{wiz_p00}->Show(0);
	$self->{t_adm_name}->SetToolTipString(_T("Een omschrijving van deze administratie, bijvoorbeeld \"Boekhouding 2009\"."));
	$self->{t_adm_code}->SetToolTipString(_T("Een korte, unieke aanduiding van deze administratie, bijvoorbeeld \"admin2009\"."));
	$self->{sp_adm_begin}->SetToolTipString(_T("De begindatum. Het boekjaar begint op 1 januari van dit jaar."));
	$self->{ch_template}->SetSelection(0);
	$self->{wiz_p01}->Show(0);
	$self->{cb_btw}->SetToolTipString(_T("BTW toepassen"));
	$self->{cb_btw}->SetValue(1);
	$self->{ch_btw_period}->SetToolTipString(_T("De aangifteperiode voor de omzetbelasting"));
	$self->{ch_btw_period}->SetSelection(1);
	$self->{wiz_p02}->Show(0);
	$self->{cb_debiteuren}->SetToolTipString(_T("Verkoop- en Debiteurenadministratie"));
	$self->{cb_debiteuren}->SetValue(1);
	$self->{cb_crediteuren}->SetToolTipString(_T("Inkoop- en Crediteurenadministratie"));
	$self->{cb_crediteuren}->SetValue(1);
	$self->{cb_kas}->SetToolTipString(_T("Kas (contant geld)"));
	$self->{cb_kas}->SetValue(1);
	$self->{cb_bank}->SetToolTipString(_T("Er wordt gebruik gemaakt van een bankrekening"));
	$self->{cb_bank}->SetValue(1);
	$self->{wiz_p03}->Show(0);
	$self->{t_db_name}->SetToolTipString(_T("De naam van de aan te maken database, b.v. \"admin2009\"."));
	$self->{ch_db_driver}->SetToolTipString(_T("Het databasesysteem waar de database wordt opgeslagen"));
	$self->{ch_db_driver}->SetSelection(1);
	$self->{wiz_p04}->Show(0);
	$self->{cb_cr_config}->SetValue(1);
	$self->{cb_cr_schema}->SetToolTipString(_T("Rekeningschema, dagboeken, BTW instellingen"));
	$self->{cb_cr_schema}->SetValue(1);
	$self->{cb_cr_relaties}->SetToolTipString(_T("Debiteuren en Crediteuren"));
	$self->{cb_cr_relaties}->SetValue(1);
	$self->{cb_cr_opening}->SetToolTipString(_T("Administratieve gegevens"));
	$self->{cb_cr_opening}->SetValue(1);
	$self->{cb_cr_mutaties}->SetToolTipString(_T("Mutaties (boekingen)"));
	$self->{cb_cr_mutaties}->SetValue(1);
	$self->{cb_cr_database}->SetToolTipString(_T("De database wordt aangemaakt en gevuld"));
	$self->{cb_cr_database}->SetValue(1);
	$self->{wiz_p05}->Show(0);

# end wxGlade

	$self->{cb_cr_schema  }->SetValue( ! -f "schema.dat"    );
	$self->{cb_cr_opening }->SetValue( ! -f "opening.eb"    );
	$self->{cb_cr_mutaties}->SetValue( ! -f "mutaties.eb"   );
	$self->{cb_cr_relaties}->SetValue( ! -f "relaties.eb"   );
	$self->{cb_cr_config  }->SetValue( ! ( -f $cfg->std_config
					       ||
					       -f $cfg->std_config_alt ) );

	$self->{t_db_name}->SetValue(sprintf("adm%04d",
					     1900+(localtime(time))[5]));
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::IniWiz::__do_layout

	$self->{sz_dummy} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2}= Wx::StaticBoxSizer->new($self->{sizer_2_staticbox}, wxVERTICAL);
	$self->{grid_sizer_5} = Wx::FlexGridSizer->new(6, 1, 5, 5);
	$self->{sizer_16} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4}= Wx::StaticBoxSizer->new($self->{sizer_4_staticbox}, wxVERTICAL);
	$self->{grid_db} = Wx::FlexGridSizer->new(3, 2, 5, 5);
	$self->{sizer_15} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_6}= Wx::StaticBoxSizer->new($self->{sizer_6_staticbox}, wxHORIZONTAL);
	$self->{grid_sizer_3} = Wx::FlexGridSizer->new(4, 1, 5, 5);
	$self->{sizer_14} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_8}= Wx::StaticBoxSizer->new($self->{sizer_8_staticbox}, wxHORIZONTAL);
	$self->{grid_sizer_4} = Wx::FlexGridSizer->new(2, 1, 5, 5);
	$self->{sizer_7} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_13} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_5}= Wx::StaticBoxSizer->new($self->{sizer_5_staticbox}, wxHORIZONTAL);
	$self->{grid_sizer_2} = Wx::FlexGridSizer->new(4, 2, 5, 5);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_11} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_12}= Wx::StaticBoxSizer->new($self->{sizer_12_staticbox}, wxHORIZONTAL);
	$self->{sizer_9} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_10} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_9}->Add($self->{t_main}, 1, wxBOTTOM|wxEXPAND|wxADJUST_MINSIZE, 10);
	$self->{sizer_9}->Add($self->{ch_runeb}, 0, wxBOTTOM|wxADJUST_MINSIZE, 10);
	$self->{sizer_10}->Add(1, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_10}->Add($self->{b_ok}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_9}->Add($self->{sizer_10}, 0, wxEXPAND, 0);
	$self->{sz_main}->Add($self->{sizer_9}, 1, wxALL|wxEXPAND, 10);
	$self->{sizer_12}->Add($self->{label_7}, 1, wxALL|wxEXPAND|wxADJUST_MINSIZE, 10);
	$self->{sizer_11}->Add($self->{sizer_12}, 1, wxEXPAND, 0);
	$self->{wiz_p00}->SetSizer($self->{sizer_11});
	$self->{sz_main}->Add($self->{wiz_p00}, 0, wxEXPAND, 0);
	$self->{grid_sizer_2}->Add($self->{label_3}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_adm_name}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{label_10}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{t_adm_code}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{label_4}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{label_6}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{sp_adm_begin}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{sizer_3}, 1, wxEXPAND, 0);
	$self->{grid_sizer_2}->Add($self->{label_9}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->Add($self->{ch_template}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_2}->AddGrowableCol(1);
	$self->{sizer_5}->Add($self->{grid_sizer_2}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_13}->Add($self->{sizer_5}, 1, wxEXPAND, 0);
	$self->{wiz_p01}->SetSizer($self->{sizer_13});
	$self->{sz_main}->Add($self->{wiz_p01}, 0, wxEXPAND, 0);
	$self->{grid_sizer_4}->Add($self->{cb_btw}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{l_btw_period}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{sizer_7}->Add($self->{ch_btw_period}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{grid_sizer_4}->Add($self->{sizer_7}, 1, wxEXPAND, 0);
	$self->{grid_sizer_4}->AddGrowableCol(0);
	$self->{sizer_8}->Add($self->{grid_sizer_4}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_14}->Add($self->{sizer_8}, 1, wxEXPAND, 0);
	$self->{wiz_p02}->SetSizer($self->{sizer_14});
	$self->{sz_main}->Add($self->{wiz_p02}, 0, wxEXPAND, 0);
	$self->{grid_sizer_3}->Add($self->{cb_debiteuren}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add($self->{cb_crediteuren}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add($self->{cb_kas}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_3}->Add($self->{cb_bank}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_6}->Add($self->{grid_sizer_3}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_15}->Add($self->{sizer_6}, 1, wxEXPAND, 0);
	$self->{wiz_p03}->SetSizer($self->{sizer_15});
	$self->{sz_main}->Add($self->{wiz_p03}, 0, wxEXPAND, 0);
	$self->{grid_db}->Add($self->{label_1}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_db}->Add($self->{t_db_name}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_db}->Add($self->{label_2}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_db}->Add($self->{ch_db_driver}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_db}->AddGrowableCol(1);
	$self->{sizer_4}->Add($self->{grid_db}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_16}->Add($self->{sizer_4}, 1, wxEXPAND, 0);
	$self->{wiz_p04}->SetSizer($self->{sizer_16});
	$self->{sz_main}->Add($self->{wiz_p04}, 0, wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{label_5}, 0, wxLEFT|wxRIGHT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{grid_sizer_5}->Add($self->{cb_cr_config}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_5}->Add($self->{cb_cr_schema}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_5}->Add($self->{cb_cr_relaties}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_5}->Add($self->{cb_cr_opening}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_5}->Add($self->{cb_cr_mutaties}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_5}->Add($self->{cb_cr_database}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{grid_sizer_5}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_2}->Add($self->{label_8}, 0, wxALL|wxADJUST_MINSIZE, 5);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxEXPAND, 5);
	$self->{wiz_p05}->SetSizer($self->{sizer_1});
	$self->{sz_main}->Add($self->{wiz_p05}, 0, wxEXPAND, 0);
	$self->{p_dummy}->SetSizer($self->{sz_main});
	$self->{sz_dummy}->Add($self->{p_dummy}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sz_dummy});
	$self->{sz_dummy}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub OnPageChanging {
    my ($self,  $event) = @_;
    return unless $event->GetDirection;
    my $page = $event->GetPage;
    return unless $page->GetId == $self->{wiz_p01}->GetId;

    my $nu = sub {
	my $m = Wx::MessageDialog->new($self->{wiz}, shift,
				       _T("Niet uniek"),
				       wxICON_ERROR|wxOK );
	my $ret = $m->ShowModal;
	$m->Destroy;
	return $ret;
    };

    my $c = $self->{t_adm_name}->GetValue;
    foreach ( @adm_names ) {
	next unless lc($_) eq lc($c);
	$nu->( _T("Er bestaat al een administratie met deze naam.") );
	$event->Veto;
	# The code will probable also be duplicate.
	# Prevent double warning.
	return;
    }
    $c = $self->{t_adm_code}->GetValue;
    foreach ( @adm_dirs ) {
	next unless lc($_) eq lc($c);
	$nu->( _T("Er bestaat al een administratie met deze code.") );
	$event->Veto;
	last;
    }
}

sub OnToggleBTW {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnToggleBTW <event_handler>

    $self = $self->GetParent;

    my $x = $self->{cb_btw}->IsChecked ? 1 : 0;
    $self->{ch_btw_period}->Enable($x);
    $self->{l_btw_period}->Enable($x);

# end wxGlade
}

sub OnSelectTemplate {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnSelectTemplate <event_handler>

    $self = $self->GetParent;

    my $x = $self->{ch_template}->GetSelection;
    if ( $x ) {
	$self->{cb_btw}->SetValue(1);
	$self->{cb_btw}->Enable(0);
	$self->{ch_btw_period}->Enable(1);
	$self->{l_btw_period}->Enable(1);
	Wx::WizardPageSimple::Chain( $self->{wiz_p02}, $self->{wiz_p04} );
    }
    else {
	$self->{cb_btw}->Enable(1);
	Wx::WizardPageSimple::Chain( $self->{wiz_p02}, $self->{wiz_p03} );
    }

# end wxGlade
}

sub OnSelectAdmName {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnSelectAdmName <event_handler>

    $self = $self->GetParent;

    my $x = lc $self->{t_adm_name}->GetValue;
    $x =~ s/\s+/_/g;
    $x =~ s/\W//g;
    $x .= "_" . $self->{sp_adm_begin}->GetValue;
    $self->{t_adm_code}->SetValue($x);
    $self->{t_db_name}->SetValue($x);

# end wxGlade
}

sub OnSelectAdmCode {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnSelectAdmCode <event_handler>

    $self = $self->GetParent;

    my $x = lc $self->{t_adm_code}->GetValue;
    $x =~ s/\s+/_/g;
    $x =~ s/\W//g;
    # $x .= "_" . $self->{sp_adm_begin}->GetValue;
    $self->{t_db_name}->SetValue($x);

# end wxGlade
}

sub OnToggleCreate {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnToggleBTW <event_handler>

    $self = $self->GetParent;

    my $x = $event->GetEventObject->IsChecked ? 1 : 0;
    $self->{ "cb_cr_$_" }->SetValue($x)
      foreach qw(schema relaties opening mutaties);

# end wxGlade
}

sub OnWizardFinished {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnWizardFinished <event_handler>

    $self->{wiz}->Destroy;
    $self->Show(1);

    my %opts;
    $opts{adm_naam} = $self->{t_adm_name}->GetValue;
    $opts{adm_code} = $self->{t_adm_code}->GetValue;
    $opts{adm_begindatum} = $self->{sp_adm_begin}->GetValue;

    $opts{db_naam} = $self->{t_db_name}->GetValue;
    $opts{db_driver} = $db_drivers[$self->{ch_db_driver}->GetSelection];
    #$opts{db_path} = $self->{dc_dbpath}->GetPath
    #  if $self->{dc_dbpath}->IsEnabled
    #	&& $self->{dc_dbpath}->GetPath !~ /^--/;
    $opts{"has_$_"} = $self->{"cb_$_"}->IsChecked
	foreach qw(debiteuren crediteuren kas bank btw);

    $opts{"create_$_"} = $self->{"cb_cr_$_"}->IsChecked
	foreach qw(config schema relaties opening mutaties database);

    $opts{adm_btwperiode} = qw(maand kwartaal jaar)[$self->{ch_btw_period}->GetSelection]
	if $opts{has_btw};

    $opts{template} = @ebz[ $self->{ch_template}->GetSelection ];

    if ( $opts{adm_code} ) {
	mkdir($opts{adm_code}) unless -d $opts{adm_code};
	chdir($opts{adm_code}) or die("chdir($opts{adm_code}): $!\n");;
    }

    eval {

	EB::Tools::MiniAdm->sanitize(\%opts);

	foreach my $c ( qw(config schema relaties opening mutaties database) ) {
	    $self->{t_main}->AppendText(__x("Aanmaken {cfg}: ",
					    cfg => $c));
	    if ( $self->{"cb_cr_$c"}->IsChecked ) {
		if ( $c eq "database" ) {

		    my $ret;
		    if ( 0 ) {
			# We can inline this, but it currently has no
			# real advantage. So it's better to avoid the
			# EB Shell code in this program.
			undef $cfg;
			EB::Config->init_config( { app => $EekBoek::PACKAGE, %opts } );
			require EB::Main;
			local @ARGV = qw( --init );
			$ret = EB::Main->run;
		    }
		    else {
			my @cmd = ( $^X, "-S", "ebshell", "--init" );
			$cmd[2] = "ebshell.pl" if $^O =~ /mswin/i;
			$ret = system(@cmd);
		    }

		    $self->{t_main}->AppendText(_T( $ret ? "Mislukt" : "Gereed")."\n");
		}
		else {
		    my $m = "generate_". $c;
		    EB::Tools::MiniAdm->$m(\%opts);
		    $self->{t_main}->AppendText(_T("Gereed")."\n");
		}
	    }
	    else {
		$self->{t_main}->AppendText(_T("Overgeslagen")."\n");
	    }
	}
    };

    $self->{t_main}->AppendText($@) if $@;

    $self->{b_ok}->Enable(1);

    unless ( -e $cfg->std_config || -e $cfg->std_config_alt ) {
	$self->{ch_runeb}->SetValue(0);
    }
    else {
	foreach ( @configs ) {
	    $self->{ch_runeb}->SetValue(0) unless -s $_;
	}
    }

# end wxGlade
}

sub OnWizardCancel {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnWizardCancel <event_handler>

    $self->{wiz}->Destroy;
    $self->Show(1);
    $self->{t_main}->SetValue(_T("Afgebroken!")."\n");
    $self->{b_ok}->Enable(1);
    $self->{ch_runeb}->SetValue(0);

# end wxGlade
}


sub OnOk {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::IniWiz::OnOk <event_handler>

    $runeb = $self->{ch_runeb}->IsChecked;
    $self->Destroy;

# end wxGlade
}

sub find_db_drivers {
    my %drivers;

    foreach my $lib ( @INC ) {
	next unless -d "$lib/EB/DB";
	foreach my $drv ( glob("$lib/EB/DB/*.pm") ) {
	    open( my $fd, "<", $drv ) or next;
	    while ( <$fd> ) {
		if ( /sub\s+type\s*{\s*"([^"]+)"\s*;?\s*}/ ) {
		    my $s = $1;
		    my $t = substr($drv,length("$lib/EB/DB/"));
		    $t =~ s/\.pm$//;
		    $drivers{lc($t)} ||= $s;
		    last;
		}
	    }
	    close($fd);
	}
    }
    \%drivers;
}

# end of class EB::Wx::IniWiz

1;

package Wx::WizardPanel;

use Wx qw[:everything];
use EB;
#use Wx::Locale gettext => '_T';

sub new {
    my ( $class, $self ) = @_;
    $self = $self->GetParent;
    $self->{wiz} ||= Wx::Wizard->new( $self, -1, _T("The Wiz"),
				      Wx::Bitmap->new("ebwiz.jpg",
						      wxBITMAP_TYPE_ANY
						     ));
    Wx::WizardPageSimple->new( $self->{wiz} );
}

package EB::Wx::IniWiz;

sub run {
    my ( $self, $opts ) = @_;
    my $admdir = $opts->{admdir} || $cfg->val(qw(general admdir), $cfg->user_dir("admdir"));
    $runeb = 1;
    $admdir =~ s/\$([A-Z_]+)/$ENV{$1}/ge;
    if ( $admdir ) {
	mkdir($admdir) unless -d $admdir;
	die("No admdir $admdir: $!") unless -d $admdir;
    }
    $opts->{admdir} = $admdir;
    $runeb = 0;

    no warnings 'redefine';
    local *Wx::App::OnInit = sub{1};

    $app = Wx::App->new();
    $app->SetAppName($EekBoek::PACKAGE);
    $app->SetVendorName("Squirrel Consultancy");

    if ( $^O =~ /^mswin/i ) {
	Wx::ConfigBase::Get->SetPath("/ebwxiniwiz");
    }
    else {
	Wx::ConfigBase::Set
	    (Wx::FileConfig->new
	     ( $app->GetAppName() ,
	       $app->GetVendorName() ,
	       $cfg->user_dir("ebwxiniwiz"),
	       '',
	       wxCONFIG_USE_LOCAL_FILE,
	     ));
    }
    Wx::ConfigBase::Get->Write('general/appversion',  $EekBoek::VERSION);

    my $ret = wxID_NEW;
    $ret = EB::Wx::IniWiz->getadm($opts) if $admdir;
    if ( $ret == wxID_CANCEL ) {
	$runeb = 0;
    }
    elsif ( $ret == wxID_NEW || ! ( -s $cfg->std_config || -s $cfg->std_config_alt ) ) {	# getadm will chdir
	my $top = EB::Wx::IniWiz->new();
	$app->SetTopWindow($top);
	$top->Centre;
	$top->runwiz;
	$app->MainLoop;
    }
    else {
	$runeb = 1;
    }

    $opts->{runeb} = $runeb;

}

1;
