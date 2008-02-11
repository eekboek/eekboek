#! perl

# $Id: BTWAangifte.pm,v 1.7 2008/02/11 15:09:43 jv Exp $

package main;

our $state;
our $dbh;

package EB::Wx::Report::BTWAangifte;

use Wx qw[:everything];
use Wx::Html;
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use strict;
use EB;

# begin wxGlade: ::dependencies
# end wxGlade

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Report::BTWAangifte::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{b_refresh} = Wx::Button->new($self, wxID_REFRESH, "");
	$self->{b_props} = Wx::Button->new($self, wxID_PREFERENCES, "");
	$self->{l_periode} = Wx::StaticText->new($self, -1, _T("Periode"), wxDefaultPosition, wxDefaultSize, );
	$self->{b_print} = Wx::Button->new($self, wxID_PRINT, "");
	$self->{b_close} = Wx::Button->new($self, wxID_CLOSE, "");
	$self->{w_report} = Wx::HtmlWindow->new($self, -1, wxDefaultPosition, wxDefaultSize, );

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, wxID_REFRESH, \&OnRefresh);
	Wx::Event::EVT_BUTTON($self, wxID_PREFERENCES, \&OnProps);
	Wx::Event::EVT_BUTTON($self, wxID_PRINT, \&OnPrint);
	Wx::Event::EVT_BUTTON($self, wxID_CLOSE, \&OnClose);

# end wxGlade

	$self->{year} = substr($dbh->adm("begin"), 0, 4);
	$self->{btwp} = $dbh->adm("btwperiod");

	$self->{_PRINTER} =  Wx::HtmlEasyPrinting->new('Print');

	return $self;

}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::BTWAangifte::__set_properties

	$self->SetTitle(_T("BTW  aangifte"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(360, 220)));
	$self->{b_refresh}->SetToolTipString(_T("Bijwerken naar laatste gegevens"));
	$self->{b_props}->SetToolTipString(_T("Instellingsgegevens"));
	$self->{b_close}->SetToolTipString(_T("Venster sluiten"));
	$self->{b_close}->SetFocus();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::BTWAangifte::__do_layout

	$self->{sz_outer} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_report} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_tools} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sz_tools}->Add($self->{b_refresh}, 0, wxLEFT|wxTOP|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_tools}->Add($self->{b_props}, 0, wxLEFT|wxTOP|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_tools}->Add(5, 1, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_tools}->Add($self->{l_periode}, 1, wxTOP|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_tools}->Add(5, 1, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sz_tools}->Add($self->{b_print}, 0, wxRIGHT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sz_tools}->Add($self->{b_close}, 0, wxRIGHT|wxTOP|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sz_report}->Add($self->{sz_tools}, 0, wxBOTTOM|wxEXPAND, 5);
	$self->{sz_report}->Add($self->{w_report}, 1, wxEXPAND, 0);
	$self->{sz_outer}->Add($self->{sz_report}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sz_outer});
	$self->Layout();

# end wxGlade
}

sub init {
    my ($self, $me) = @_;
    $self->refresh;
}

sub refresh {
    my ($self) = @_;
    require EB::Report::BTWAangifte;
    my $output;
    EB::Report::BTWAangifte->new->perform
	({ backend => 'EB::Report::BTWAangifte::WxHtml',
	   boekjaar => $state->bky,
	   output => \$output,
	   detail => $self->{detail} });
    $output = "<h1>Output</h1>" unless $output =~ /\<tr\>/;
    $self->{w_report}->SetPage($output);
    $self->{_HTMLTEXT} = $output;
}

sub html     { $_[0]->{w_report}  }
sub htmltext { $_[0]->{_HTMLTEXT} }
sub printer  { $_[0]->{_PRINTER}  }

sub set_periode {
   my ($self, $p) = @_;
   if ( $p eq "j" ) {
       $p = "Gehele jaar";
   }
   elsif ( $p =~ /^k(\d+)$/ ) {
       $p = (qw(Eerste Tweede Derde Vierde)[$1-1] . " kwartaal");
   }
   elsif ( $p =~ /^m(\d+)$/ ) {
       $p = (qw(Januari Februari Maart April Mei Juni Juli Augustus September Oktober November December)[$1-1]);
   }
   $self->{l_periode}->SetLabel(_T("Periode:")." ".$p);
   $self->Layout;
}

# wxGlade: EB::Wx::Report::BTWAangifte::OnRefresh <event_handler>
sub OnRefresh {
    my ($self, $event) = @_;
    $self->refresh;
}

# wxGlade: EB::Wx::Report::BTWAangifte::OnProps <event_handler>
sub OnProps {
    my ($self, $event) = @_;
    use EB::Wx::Report::BTWAangifte::Preferences;
    my $d = EB::Wx::Report::BTWAangifte::Preferences->new
      ($self, -1, "Selecteer", wxDefaultPosition, wxDefaultSize,);
    my $ret = $d->ShowModal;
    if ( $ret == wxID_OK ) {
	$self->set_periode($d->{periode});
    }
    $d->Destroy;
}

# wxGlade: EB::Wx::Report::BTWAangifte::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;
    $self->sizepos_save;
    $self->Show(0);
}

# wxGlade: EB::Wx::Report::BTWAangifte::OnPrint <event_handler>
sub OnPrint {
    my ($self, $event) = @_;
    $self->printer->SetFooter(_T("Blad:").' @PAGENUM@');
    $self->printer->PrintText($self->htmltext);
}

# end of class EB::Wx::Report::BTWAangifte

################ Report handler ################

package EB::Report::BTWAangifte::WxHtml;

use EB;
use base qw(EB::Report::Reporter::WxHtml);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
    $self->{overall_font_size} = "-2";
    $self->{_OUT} = $opts->{output} if $opts->{output};
    return $self;
}

sub outline {
}

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
	d2    => {
	    desc   => { indent => 2      },
	},
	h1    => {
	    _style => { colour => 'red',
			size   => '+2',
		      }
	},
	h2    => {
	    _style => { colour => 'red'  },
	    desc   => { indent => 1,},
	},
	t1    => {
	    _style => { colour => 'blue',
			size   => '+1',
		      }
	},
	t2    => {
	    _style => { colour => 'blue' },
	    desc   => { indent => 1      },
	},
	v     => {
	    _style => { colour => 'red',
			size   => '+2',
		      }
	},
	grand => {
	    _style => { colour => 'blue' }
	},
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

1;
