#! perl

# $Id: GenBase.pm,v 1.6 2009/10/09 15:43:07 jv Exp $

package main;

our $state;
our $app;
our $dbh;

package EB::Wx::Report::GenBase;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use base qw(EB::Wx::Window);
use Wx::Html;
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

# begin wxGlade: EB::Wx::Report::GenBase::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{b_refresh} = Wx::Button->new($self, wxID_REFRESH, "");
	$self->{b_props} = Wx::Button->new($self, wxID_PREFERENCES, "");
	$self->{l_detail} = Wx::StaticText->new($self, -1, _T("Detail:"), wxDefaultPosition, wxDefaultSize, );
	$self->{bd_less} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("edit_remove.png", wxBITMAP_TYPE_ANY));
	$self->{bd_more} = Wx::BitmapButton->new($self, -1, Wx::Bitmap->new("edit_add.png", wxBITMAP_TYPE_ANY));
	$self->{b_print} = Wx::Button->new($self, wxID_PRINT, "");
	$self->{b_close} = Wx::Button->new($self, wxID_CLOSE, "");
	$self->{w_report} = Wx::HtmlWindow::Derived->new($self, -1, wxDefaultPosition, wxDefaultSize, );

	$self->__set_properties();
	$self->__do_layout();

	Wx::Event::EVT_BUTTON($self, $self->{b_refresh}->GetId, \&OnRefresh);
	Wx::Event::EVT_BUTTON($self, $self->{b_props}->GetId, \&OnProps);
	Wx::Event::EVT_BUTTON($self, $self->{bd_less}->GetId, \&OnLess);
	Wx::Event::EVT_BUTTON($self, $self->{bd_more}->GetId, \&OnMore);
	Wx::Event::EVT_BUTTON($self, wxID_PRINT, \&OnPrint);
	Wx::Event::EVT_BUTTON($self, $self->{b_close}->GetId, \&OnClose);

# end wxGlade

	Wx::Event::EVT_MENU($self, wxID_CLOSE, \&OnClose);

=begin notneeded

	# Accelerators do not work with Dialog windows.
	# Attach one to the inner w_report window.
	$self->{w_report}->SetAcceleratorTable
	  ( Wx::AcceleratorTable->new
	    ( [ wxACCEL_ALT, WXK_F4, wxID_CLOSE ] ) );
	Wx::Event::EVT_MENU($self->{w_report}, wxID_CLOSE, \&OnClose);

=cut

	$self->{_PRINTER} =  Wx::HtmlEasyPrinting->new('Print');

	return $self;

}

sub html     { $_[0]->{w_report}  }
sub htmltext :lvalue { $_[0]->{_HTMLTEXT} }
sub printer  { $_[0]->{_PRINTER}  }

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::GenBase::__set_properties

	$self->SetTitle(_T("Generiek Rapport"));
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(360, 220)));
	$self->{b_refresh}->SetToolTipString(_T("Bijwerken naar laatste gegevens"));
	$self->{b_props}->SetToolTipString(_T("Instellingsgegevens"));
	$self->{bd_less}->SetToolTipString(_T("Minder uitgebreid"));
	$self->{bd_less}->SetSize($self->{bd_less}->GetBestSize());
	$self->{bd_more}->SetToolTipString(_T("Meer uitgebreid"));
	$self->{bd_more}->SetSize($self->{bd_more}->GetBestSize());
	$self->{b_print}->SetToolTipString(_T("Overzicht afdrukken"));
	$self->{b_close}->SetToolTipString(_T("Venster sluiten"));
	$self->{b_close}->SetFocus();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Report::GenBase::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_3}->Add($self->{b_refresh}, 0, wxLEFT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_props}, 0, wxLEFT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{l_detail}, 0, wxLEFT|wxTOP|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{bd_less}, 0, wxTOP|wxEXPAND|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{bd_more}, 0, wxTOP|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add(5, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_print}, 0, wxRIGHT|wxTOP|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add($self->{b_close}, 0, wxRIGHT|wxTOP|wxEXPAND|wxADJUST_MINSIZE, 5);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxBOTTOM|wxEXPAND, 5);
	$self->{sizer_2}->Add($self->{w_report}, 1, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxEXPAND, 5);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();

# end wxGlade

}

sub SetDetails {
    my ($self, $cur, $min, $max, $tips) = @_;
    $self->{_maxdetail} = $max;
    $self->{_mindetail} = $min;
    $self->{detail} = $cur;
    $self->{_ml_tips} = $tips if $tips;
    $self->_MoreLess;
}

sub GetDetail {
    my ($self) = @_;
    $self->{detail};
}

sub OnRefresh {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::Report::GenBase::OnRefresh <event_handler>

    $self->refresh;

# end wxGlade
}

sub OnProps {
    my ($self, $event) = @_;
# wxGlade: EB::Wx::Report::GenBase::OnProps <event_handler>

    my $this = "d_repprops";

    # Try package specific prefs dialog.
    my $pkg = ref($self)."::Preferences";
    eval "require $pkg";

    # Otherwise, try generic dialog.
    if ( $@ ) {
	Wx::LogMessage($@) unless $@ =~ /Can't locate .*\/Preferences.pm in \@INC/;
	$pkg = "EB::Wx::Report::GenBase::Preferences";
	eval "require $pkg";
	die($@) if $@;
    }

    $self->{$this} ||= $pkg->new
      ($self, -1,
       "Instellingen",
       wxDefaultPosition, wxDefaultSize,
      );

    # Let it take what it wants...
    $self->{$this}->init($self);
    my $ret = $self->{$this}->ShowModal;

    # Store back (possibly updated) prefs.
    if ( $ret == wxID_OK ) {
	my $h = $self->{$this}->GetValues;
	foreach ( grep { /^pref_/ } keys(%$h) ) {
	    $self->{$_} = $h->{$_};
	}
	$self->{prefs_changed} = 1;
	$self->refresh;
	delete $self->{prefs_changed};
    }

# end wxGlade
}

# wxGlade: EB::Wx::Report::GenBase::OnMore <event_handler>
sub OnMore {
    my ($self, $event) = @_;

    if ( $self->{detail} < $self->{_maxdetail} ) {
	$self->{detail}++;
	$self->refresh;
    }
    $self->_MoreLess;
}

sub _MoreLess() {
    my $self = shift;

    if ( $self->{detail} < $self->{_maxdetail} ) {
	$self->{bd_more}->Enable(1);
	$self->{bd_more}->SetToolTipString
	  ( $self->{_ml_tips}
	    ? $self->{_ml_tips}->[$self->{detail}+1]
	    : _T("Meer uitgebreid") );
    }
    else {
	$self->{bd_more}->Enable(0);
    }

    if ( $self->{detail} > $self->{_mindetail} ) {
	$self->{bd_less}->Enable(1);
	$self->{bd_less}->SetToolTipString
	  ( $self->{_ml_tips}
	    ? $self->{_ml_tips}->[$self->{detail}-1]
	    : _T("Minder uitgebreid") );
    }
    else {
	$self->{bd_less}->Enable(0);
    }
}

# wxGlade: EB::Wx::Report::GenBase::OnLess <event_handler>
sub OnLess {
    my ($self, $event) = @_;

    if ( $self->{detail} > $self->{_mindetail} ) {
	$self->{detail}--;
	$self->refresh;
    }
    $self->_MoreLess;
}

# wxGlade: EB::Wx::Report::GenBase::OnClose <event_handler>
sub OnClose {
    my ($self, $event) = @_;

    # OnClose can be triggered from the inner window.
    while ( ! $self->can("sizepos_save") ) {
	$self = $self->GetParent;
    }

    $self->sizepos_save;
    $self->Show(0);

}

# wxGlade: EB::Wx::Report::GenBase::OnPrint <event_handler>
sub OnPrint {
    my ($self, $event) = @_;

    #$self->printer->SetHeader('@TITLE@');
    #$self->printer->SetFooter('@DATE@ @TIME@ '._T("Blad:").' @PAGENUM@');
    $self->printer->SetFooter(_T("Blad:").' @PAGENUM@');
    my $html = $self->htmltext;
    $html =~ s;</?a[^>]*>;;gx;
    $self->printer->PrintText($html);

}

package Wx::HtmlWindow::Derived;

use strict;
use warnings;
use base qw(Wx::HtmlWindow);

sub OnLinkClicked {
    my ($self, $event) = @_;
    my $link = $event->GetHref;

    if ( $link =~ m;^([^:]+)://(.+)$;
	 && (my $rep = EB::Wx::MainFrame->can("ShowR" . ucfirst(lc($1)))) ) {
	my @a = split(/[?&]/, $2);
	my $args = { select => shift(@a) };
	foreach ( @a ) {
	    if ( /^([^=]+)=(.*)/ ) {
		$args->{$1} = $2;
	    }
	    else {
		$args->{$_} = 1;
	    }
	}
	$rep->($app->{TOP}, $args);
    }
    else {
	Wx::LogMessage('Link: "%s"', $1);
	$self->SUPER::OnLinkClicked($event);
    }
}

1;

