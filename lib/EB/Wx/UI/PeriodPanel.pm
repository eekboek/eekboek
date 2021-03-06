#! perl

package main;

our $state;
our $dbh;

package EB::Wx::UI::PeriodPanel;

use Wx qw[:everything :datepicker];
use Wx::Calendar;
use base qw(Wx::Panel);
use base qw(EB::Wx::Window);

use base qw(Wx::PlWindow);
use base qw(Exporter);
our @EXPORT_OK = qw(EVT_EB_PERIOD);
our %EXPORT_TAGS = ( 'everything'   => \@EXPORT_OK,
                     'event'        => [ qw(EVT_EB_PERIOD) ],
		   );

use EB;

use strict;

sub new {
	my( $self, $parent, $id, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::UI::PeriodPanel::new

	$style = wxTAB_TRAVERSAL 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $pos, $size, $style, $name );
	$self->{label_1} = Wx::StaticText->new($self, -1, "Specificeer de gewenste periode door een\nboekjaar te kiezen of door handmatig de\ndata in te geven.", wxDefaultPosition, wxDefaultSize, );
	$self->{l_bky} = Wx::StaticText->new($self, -1, "Boekjaar:", wxDefaultPosition, wxDefaultSize, );
	$self->{c_bky} = Wx::Choice->new($self, -1, wxDefaultPosition, wxDefaultSize, ["Kies datum"], );
	$self->{t_bky} = Wx::TextCtrl->new($self, -1, "", wxDefaultPosition, wxDefaultSize, wxTE_READONLY);
	$self->{l_per_from} = Wx::StaticText->new($self, -1, "Periode vanaf", wxDefaultPosition, wxDefaultSize, );
	$self->{dt_from} = Wx::StaticText->new($self, -1, "Placeholder", wxDefaultPosition, wxDefaultSize, );
	$self->{l_per_to} = Wx::StaticText->new($self, -1, "Periode t/m", wxDefaultPosition, wxDefaultSize, );
	$self->{dt_to} = Wx::StaticText->new($self, -1, "Placeholder", wxDefaultPosition, wxDefaultSize, );

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_CHOICE($self, $self->{c_bky}->GetId, \&OnBky);

# end wxGlade

	Wx::Event::EVT_DATE_CHANGED($self, $self->{dt_from}->GetId, \&OnFromChanged);
	Wx::Event::EVT_DATE_CHANGED($self, $self->{dt_to}->GetId, \&OnToChanged);

	return $self;

}


sub __set_properties {
	my $self = shift;

	my $date = Wx::DateTime::Now;
	$self->{dt_from}->Destroy;
	$self->{dt_from} = Wx::DatePickerCtrl->new($self, -1, $date);
	$self->{dt_to}->Destroy;
	$self->{dt_to} = Wx::DatePickerCtrl->new($self, -1, $date);

# begin wxGlade: EB::Wx::UI::PeriodPanel::__set_properties

	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(172, 103)));
	$self->{c_bky}->SetMinSize(Wx::Size->new(150, 30));
	$self->{c_bky}->SetSelection(0);
	$self->{dt_from}->SetMinSize(Wx::Size->new(150, 26));
	$self->{dt_to}->SetMinSize(Wx::Size->new(150, 26));

# end wxGlade

}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::UI::PeriodPanel::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{grid_sizer_1} = Wx::FlexGridSizer->new(5, 2, 5, 5);
	$self->{sizer_4}->Add($self->{label_1}, 0, wxADJUST_MINSIZE, 0);
	$self->{sizer_4}->Add(1, 7, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{l_bky}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{c_bky}, 1, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add(1, 1, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{t_bky}, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{l_per_from}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{dt_from}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{l_per_to}, 0, wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->Add($self->{dt_to}, 0, wxADJUST_MINSIZE, 0);
	$self->{grid_sizer_1}->AddGrowableCol(1);
	$self->{sizer_4}->Add($self->{grid_sizer_1}, 1, wxEXPAND, 0);
	$self->{sizer_2}->Add($self->{sizer_4}, 1, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 0, wxLEFT|wxRIGHT|wxTOP|wxEXPAND, 5);
	$self->SetSizer($self->{sizer_1});

# end wxGlade
}

my $evt_change = Wx::NewEventType;

sub Wx::Event::EVT_EB_PERIOD($$$) {
    $_[0]->Connect($_[1], -1, $evt_change, $_[2]);
}

sub _ISOtoWxD {
    return unless shift =~ /^(\d{4})-(\d\d)-(\d\d)$/;
    Wx::DateTime->newFromDMY($3,$2-1,$1,1,1,1,1);
}

sub allow_fromto {
    my ($self, $val) = @_;
    $self->allow_to($val);
    $self->allow_from($val);
}
sub allow_to {
    my ($self, $val) = @_;
    $self->{_allow_to} = $val;
}
sub allow_from {
    my ($self, $val) = @_;
    $self->{_allow_from} = $val;

}
sub allow_all {
    my ($self, $val) = @_;
    $self->{_allow_all} = $val;

}

my @choices;
sub refresh {
    my ($self) = @_;

    my $sth = $dbh->sql_exec("SELECT bky_code, bky_begin, bky_end, bky_name FROM Boekjaren".
			     " WHERE NOT bky_opened IS NULL".
			     " AND bky_code <> ?".
			     " ORDER BY bky_begin", BKY_PREVIOUS);
    $self->{c_bky}->Clear;
    @choices = ();

    if ( $self->{_allow_all} ) {
	push(@choices, 0);
	$self->{c_bky}->Append("Alle");
    }

    my $i = 0;
    my $sel;
    my $min;
    my $max;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	push(@choices, [@$rr]);
	$self->{c_bky}->Append($rr->[0]) unless $self->{_allow_all} > 1;
	$sel = $i if $state->bky eq $choices[-1];
	$i++;
	$min = $rr->[1] if !defined($min) || $min gt $rr->[1];
	$max = $rr->[2] if !defined($max) || $max lt $rr->[2];
    }
    if ( $self->{_allow_from} || $self->{_allow_to} ) {
	push(@choices, ["Kies datum",$min,$max,""]);
	$self->{c_bky}->Append($choices[-1]->[0]) unless $self->{_allow_all} > 1;
    }
    if ( $self->{_allow_all} ) {
	$choices[0] = ["Alle", $min, $max, "Gehele administratie"];
	$sel = 0;
    }
    $self->{_bky} = $choices[$sel]->[0];
    my $begin = _ISOtoWxD($min);
    $min = _ISOtoWxD($choices[$sel]->[1]);
    $max = _ISOtoWxD($choices[$sel]->[2]);
    $self->{c_bky}->SetSelection($sel);
    $self->{t_bky}->SetValue($choices[$sel]->[3]);
    $self->{dt_from}->SetValue($self->{_fromto} ? $min : $begin);
    $self->{dt_from}->SetRange($self->{_fromto} ? $min : $begin, $max);
    $self->{dt_to}->SetValue($max);
    $self->{dt_to}->SetRange($min, $max);
    $self->{dt_from}->Enable(0);
    $self->{l_per_from}->Enable(0);
    $self->{l_per_to}->Enable(0);
    $self->{dt_to}->Enable(0);
    $self->{_changed} = 0;
}

sub OnBky {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::UI::PeriodPanel::OnBky <event_handler>

    my $sel = $self->{c_bky}->GetSelection;
    $self->set_bky(undef, $sel);
    $self->{_changed}++;
    $self->GetEventHandler->ProcessEvent
      (EB::Wx::UI::PeriodPanel::Event->new($evt_change, $self->GetId));

# end wxGlade
}

sub set_bky {
    my ($self, $bky, $sel) = @_;
    unless ( defined($sel) ) {
	for ( my $s=0; $s < @choices; $s++ ) {
	    $sel = $s, last if $choices[$s]->[0] eq $bky;
	}
    }
    return unless defined $sel;

    my $min = _ISOtoWxD($choices[$sel]->[1]);
    my $max = _ISOtoWxD($choices[$sel]->[2]);

    if ( $self->{_allow_from} ) {
	$self->{dt_from}->SetValue($min);
	$self->{dt_from}->SetRange($min, $max);
    }
    $self->{dt_to}->SetValue($max);
    $self->{dt_to}->SetRange($min, $max);
    $self->{t_bky}->SetValue($choices[$sel]->[3]);
    if ( ($self->{_allow_from} || $self->{_allow_to}) && $sel == $#choices ) {
	undef $self->{_bky};
	if ( $self->{_allow_from} ) {
	    $self->{dt_from}->Enable(1);
	    $self->{l_per_from}->Enable(1);
	}
	if ( $self->{_allow_to} ) {
	    $self->{dt_to}->Enable(1);
	    $self->{l_per_to}->Enable(1);
	}
	$self->{_bky} = undef;
    }
    else {
	$self->{c_bky}->SetSelection($sel);
	$self->{dt_to}->Enable(0);
	$self->{dt_from}->Enable(0);
	$self->{l_per_from}->Enable(0);
	$self->{l_per_to}->Enable(0);
	$self->{_bky} = $choices[$sel]->[0];
    }
}

sub OnFromChanged {
    my ($self, $event) = @_;
    $self->{_changed}++;
    $self->GetEventHandler->ProcessEvent
      (EB::Wx::UI::PeriodPanel::Event->new($evt_change, $self->GetId));
}

sub OnToChanged {
    my ($self, $event) = @_;
    $self->{_changed}++;
    $self->GetEventHandler->ProcessEvent
      (EB::Wx::UI::PeriodPanel::Event->new($evt_change, $self->GetId));
}

sub changed {
    my ($self) = @_;
    $self->{_changed};
}

sub GetValues {
    my ($self) = @_;

    my $ret = {};

    $ret->{period_panel_bky}  = $self->{_bky};
    $ret->{period_panel_from} = $self->{dt_from}->GetValue->FormatISODate
      if $self->{_allow_from};
    $ret->{period_panel_to}   = $self->{dt_to}->GetValue->FormatISODate
      if $self->{_allow_to};
    $ret->{period_panel_all}  = $self->{c_bky}->GetSelection == 0
      if $self->{_allow_all};
    $ret;
}

# end of class EB::Wx::UI::PeriodPanel

package EB::Wx::UI::PeriodPanel::Event;
use base qw(Wx::PlCommandEvent);

1;
