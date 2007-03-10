package main;

our $cfg;
our $config;
our $app;
our $dbh;

package EB::Wx::Tools::PropertiesDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
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

	$style = wxRESIZE_BORDER|wxCLOSE_BOX|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{l_dbname} = Wx::StaticText->new($self, -1, _T("Database"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_dbname} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_admname} = Wx::StaticText->new($self, -1, _T("Administratie"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_admname} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_open} = Wx::StaticText->new($self, -1, _T("Geopend"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_open} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_boekjaar} = Wx::StaticText->new($self, -1, _T("Boekjaar"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_boekjaar} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_btw} = Wx::StaticText->new($self, -1, _T("BTW periode"), wxDefaultPosition, wxDefaultSize, );
	$self->{t_btw} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{static_line_1} = Wx::StaticLine->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{b_accept} = Wx::Button->new($self, wxID_CLOSE, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, wxID_CLOSE, \&OnClose);

# end wxGlade

	$self->{mew} = "prpw";

	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PropertiesDialog::__set_properties

	$self->SetTitle(_T("Eigenschappen"));

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PropertiesDialog::__do_layout

	$self->{s_outer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{s_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_grid} = Wx::FlexGridSizer->new(5, 2, 3, 3);
	$self->{s_grid}->Add($self->{l_dbname}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_dbname}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_admname}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_admname}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_open}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_open}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_boekjaar}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_boekjaar}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{l_btw}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{t_btw}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_grid}->AddGrowableCol(1);
	$self->{s_main}->Add($self->{s_grid}, 0, wxEXPAND, 0);
	$self->{s_main}->Add(1, 5, 1, wxADJUST_MINSIZE, 0);
	$self->{s_main}->Add($self->{static_line_1}, 0, wxBOTTOM|wxEXPAND|wxALIGN_BOTTOM, 5);
	$self->{s_buttons}->Add(5, 1, 1, wxADJUST_MINSIZE, 0);
	$self->{s_buttons}->Add($self->{b_accept}, 0, wxRIGHT|wxADJUST_MINSIZE, 5);
	$self->{s_buttons}->Add(5, 1, 1, wxADJUST_MINSIZE, 0);
	$self->{s_main}->Add($self->{s_buttons}, 0, wxEXPAND, 0);
	$self->{s_outer}->Add($self->{s_main}, 1, wxALL|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->SetSizer($self->{s_outer});
	$self->{s_outer}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub refresh {
    my ($self) = @_;
    my $t = $cfg->val(qw(database name));
    $t =~ s/^eekboek_//;
    $t .= " (" . $dbh->driverdb . ")";
    $self->{t_dbname}->SetValue($t);
    $self->{t_admname}->SetValue($dbh->adm("name"));
    $self->{t_open}->SetValue($dbh->adm("opened"));
    $self->{t_boekjaar}->SetValue($dbh->adm("bky"));
    $self->{t_btw}->SetValue(BTWPERIODES->[$dbh->adm("btwperiod")]);
}

# wxGlade: EB::Wx::Tools::PropertiesDialog::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    @{$config->get($self->{mew})}{qw(xpos ypos xwidth ywidth)} =
      ($self->GetPositionXY, $self->GetSizeWH);
    $self->Show(0);
}

# end of class EB::Wx::Tools::PropertiesDialog

1;

