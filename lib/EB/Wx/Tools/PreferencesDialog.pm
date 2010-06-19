#! perl

package main;

our $state;
our $dbh;

package EB::Wx::Tools::PreferencesDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;

use Wx::Locale gettext => '_T';
sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Tools::PreferencesDialog::new

	$style = wxDEFAULT_DIALOG_STYLE 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{s_main_staticbox} = Wx::StaticBox->new($self, -1, _T("Voorkeursinstellingen") );
	$self->{c_splash} = Wx::CheckBox->new($self, -1, _T("Toon welkom-scherm bij opstarten"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_tips} = Wx::CheckBox->new($self, -1, _T("Toon hints bij opstarten"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_verbose} = Wx::CheckBox->new($self, -1, _T("Uitgebreide log-informatie"), wxDefaultPosition, wxDefaultSize, );
	$self->{c_trace} = Wx::CheckBox->new($self, -1, _T("Trace SQL aanroepen"), wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");
	$self->{b_accept} = Wx::Button->new($self, wxID_APPLY, "");

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_CHECKBOX($self, $self->{c_splash}->GetId, \&OnClick);
	Wx::Event::EVT_CHECKBOX($self, $self->{c_tips}->GetId, \&OnClick);
	Wx::Event::EVT_CHECKBOX($self, $self->{c_verbose}->GetId, \&OnClick);
	Wx::Event::EVT_CHECKBOX($self, $self->{c_trace}->GetId, \&OnClick);
	Wx::Event::EVT_BUTTON($self, $self->{b_cancel}->GetId, \&OnCancel);
	Wx::Event::EVT_BUTTON($self, $self->{b_accept}->GetId, \&OnApply);

# end wxGlade

	Wx::Event::EVT_IDLE($self, \&OnIdle);

	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PreferencesDialog::__set_properties

	$self->SetTitle(_T("Voorkeursinstellingen"));
	$self->{c_splash}->SetValue(1);
	$self->{c_tips}->SetValue(1);
	$self->{c_verbose}->SetValue(1);
	$self->{b_cancel}->SetFocus();
	$self->{b_accept}->Enable(0);
	$self->{b_accept}->SetDefault();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::PreferencesDialog::__do_layout

	$self->{s_outer} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{s_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{s_main}= Wx::StaticBoxSizer->new($self->{s_main_staticbox}, wxVERTICAL);
	$self->{s_grid} = Wx::FlexGridSizer->new(4, 1, 3, 3);
	$self->{s_grid}->Add($self->{c_splash}, 0, wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{c_tips}, 0, wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{c_verbose}, 0, wxADJUST_MINSIZE, 0);
	$self->{s_grid}->Add($self->{c_trace}, 0, wxADJUST_MINSIZE, 0);
	$self->{s_grid}->AddGrowableCol(1);
	$self->{s_main}->Add($self->{s_grid}, 0, wxEXPAND, 0);
	$self->{s_outer}->Add($self->{s_main}, 0, wxALL|wxEXPAND, 5);
	$self->{s_buttons}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{s_buttons}->Add($self->{b_cancel}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{s_buttons}->Add($self->{b_accept}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
	$self->{s_outer}->Add($self->{s_buttons}, 0, wxLEFT|wxRIGHT|wxBOTTOM|wxEXPAND, 5);
	$self->SetSizer($self->{s_outer});
	$self->{s_outer}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub refresh {
    my ($self) = @_;
    $self->{c_splash }->SetValue($state->showsplash);
    $self->{c_tips   }->SetValue($state->showtips  );
    $self->{c_verbose}->SetValue($state->verbose   );
    $self->{c_trace  }->SetValue($state->trace     );
    $self->{b_accept}->Enable(0);
    $self->{b_accept}->SetDefault();
    $self->{b_cancel}->SetFocus();
    $self->{_check_changed} = 0;
}

sub changed {
    my ($self) = @_;
    return 1 if $self->{c_splash }->GetValue != $state->showsplash;
    return 2 if $self->{c_tips   }->GetValue != $state->showtips  ;
    return 4 if $self->{c_verbose}->GetValue != $state->verbose   ;
    return 8 if $self->{c_trace  }->GetValue != $state->trace     ;
    return;
}

# wxGlade: EB::Wx::Tools::PreferencesDialog::OnIdle <event_handler>
sub OnIdle {
    my ($self) = @_;
    return unless $self->{_check_changed};
    $self->{b_accept}->Enable(0+$self->changed);
    $self->{_check_changed} = 0;
}

# wxGlade: EB::Wx::Tools::PreferencesDialog::OnApply <event_handler>
sub OnApply {
    my ($self, $event) = @_;
    $state->showsplash(0+$self->{c_splash }->GetValue);
    $state->showtips(  0+$self->{c_tips   }->GetValue);
    $state->verbose(   0+$self->{c_verbose}->GetValue);
    $state->trace(     0+$self->{c_trace  }->GetValue);
    $dbh->trace($state->trace);
    $self->OnClose($event);
}

# wxGlade: EB::Wx::Tools::PreferencesDialog::OnClick <event_handler>
sub OnClick {
    my ($self, $event) = @_;
    $self->{_check_changed}++;
}

# wxGlade: EB::Wx::Tools::PreferencesDialog::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    $self->sizepos_save;
    $self->Show(0);
}

# wxGlade: EB::Wx::Tools::PreferencesDialog::OnCancel <event_handler>
sub OnCancel {
    my ($self, $event) = @_;
    $self->OnClose($event);
}

1;
