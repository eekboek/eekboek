#! perl

# $Id: Preferences.pm,v 1.3 2008/02/11 15:14:07 jv Exp $

package EB::Wx::Report::GenBase::Preferences;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use EB::Wx::UI::PeriodPanel;
use strict;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Report::GenBase::Preferences::new

	$style = wxDEFAULT_DIALOG_STYLE 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{sizer_2_staticbox} = Wx::StaticBox->new($self, -1, "" );
	$self->{p_period} = EB::Wx::UI::PeriodPanel->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{b_cancel} = Wx::Button->new($self, wxID_CANCEL, "");
	$self->{b_apply} = Wx::Button->new($self, wxID_OK, "");

	$self->__set_properties();
	$self->__do_layout();

# end wxGlade

	Wx::Event::EVT_EB_PERIOD($self, $self->{p_period}, \&OnPeriod);

	return $self;

}


sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::GenBase::Preferences::__set_properties

	$self->SetTitle("Instellingen");
	$self->{b_cancel}->SetFocus();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::GenBase::Preferences::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2}= Wx::StaticBoxSizer->new($self->{sizer_2_staticbox}, wxHORIZONTAL);
	$self->{sizer_2}->Add($self->{p_period}, 1, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 0, wxLEFT|wxRIGHT|wxEXPAND, 5);
	$self->{sizer_3}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_cancel}, 0, wxALL|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_apply}, 0, wxALL|wxADJUST_MINSIZE, 5);
	$self->{sizer_1}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->{sizer_1}->Fit($self);
	$self->Layout();

# end wxGlade
}

sub init {
    my ($self, $args) = @_;
    if ( $args->{pref_from_to} ) {
	$self->{p_period}->allow_fromto(1) if $args->{pref_from_to} & 1;
	$self->{p_period}->allow_to(1)     if $args->{pref_from_to} & 2;
    }
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    $self->{p_period}->refresh;
    $self->{b_apply}->Enable(0);
}

sub GetValues {
    my ($self) = @_;
    my $r;
    my $p = $self->{p_period}->GetValues;
    $r->{pref_bky}      = $p->{period_panel_bky}  if exists $p->{period_panel_bky};
    $r->{pref_per}->[0] = $p->{period_panel_from} if exists $p->{period_panel_from};
    $r->{pref_per}->[1] = $p->{period_panel_to}   if exists $p->{period_panel_to};
    $r;
}

sub OnPeriod {
    my ($self, $event) = @_;
    use Data::Dumper; warn(Dumper($event));
    $self->{b_apply}->Enable($self->{p_period}->changed);
}

# end of class EB::Wx::Report::GenBase::Preferences

1;
