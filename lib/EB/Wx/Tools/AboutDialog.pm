#! perl

package EB::Wx::Tools::AboutDialog;

use Wx qw[:everything];
use base qw(Wx::Dialog);
use strict;

sub new {
	my( $self, $parent, $id, $title, $pos, $size, $style, $name ) = @_;
	$parent = undef              unless defined $parent;
	$id     = -1                 unless defined $id;
	$title  = ""                 unless defined $title;
	$pos    = wxDefaultPosition  unless defined $pos;
	$size   = wxDefaultSize      unless defined $size;
	$name   = ""                 unless defined $name;

# begin wxGlade: EB::Wx::Tools::AboutDialog::new

	$style = wxDEFAULT_DIALOG_STYLE|wxRESIZE_BORDER|wxTHICK_FRAME 
		unless defined $style;

	$self = $self->SUPER::new( $parent, $id, $title, $pos, $size, $style, $name );
	$self->{bitmap_1} = Wx::StaticBitmap->new($self, -1, Wx::Bitmap->new("eb.jpg", wxBITMAP_TYPE_ANY), wxDefaultPosition, wxDefaultSize, );
	$self->{p_html} = EB::Wx::Tools::AboutDialog::HtmlWindow->new($self, -1, wxDefaultPosition, wxDefaultSize, );
	$self->{b_ok} = Wx::Button->new($self, wxID_OK, "");

	$self->__set_properties();
	$self->__do_layout();

# end wxGlade

	return $self;

}

sub __set_properties {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::AboutDialog::__set_properties

	$self->SetTitle("Info");
	$self->SetSize($self->ConvertDialogSizeToPixels(Wx::Size->new(232, 136)));
	$self->SetBackgroundColour(Wx::Colour->new(255, 255, 255));
	$self->{b_ok}->SetFocus();

# end wxGlade
}

sub __do_layout {
	my $self = shift;

# begin wxGlade: EB::Wx::Tools::AboutDialog::__do_layout

	$self->{sizer_1} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_2} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sizer_3} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4} = Wx::BoxSizer->new(wxHORIZONTAL);
	$self->{sizer_4}->Add($self->{bitmap_1}, 0, wxALL|wxALIGN_CENTER_VERTICAL|wxADJUST_MINSIZE, 5);
	$self->{sizer_4}->Add($self->{p_html}, 1, wxALL|wxEXPAND, 5);
	$self->{sizer_2}->Add($self->{sizer_4}, 1, wxEXPAND, 0);
	$self->{sizer_3}->Add(1, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_3}->Add($self->{b_ok}, 0, wxALL|wxADJUST_MINSIZE, 5);
	$self->{sizer_3}->Add(1, 1, 1, wxEXPAND|wxADJUST_MINSIZE, 0);
	$self->{sizer_2}->Add($self->{sizer_3}, 0, wxEXPAND, 0);
	$self->{sizer_1}->Add($self->{sizer_2}, 1, wxEXPAND, 0);
	$self->SetSizer($self->{sizer_1});
	$self->Layout();

# end wxGlade
}

# end of class EB::Wx::Tools::AboutDialog

sub init {
}

sub refresh {
    my ($self) = @_;

    my $info = "<p>";

    my $msg = $EB::imsg . "\n";
    $info .= $msg . "</p>\n";
    my $v = $Wx::VERSION;
    $v =~ s/,/./g;
    $info .= "<p>wxPerl versie $v<br>\n";
    $info .= sprintf("Perl versie %vd<br>\n", $^V);
    $v = Wx::wxVERSION;
    $v =~ s/,/./g;
    $v = sprintf("%d.%d.%d", $1, $2, $3) if $v =~ /^(\d+)\.(\d\d\d)(\d\d\d)$/;
    $info .= "wxWidgets versie $v</p>\n";
    $info .= "<p>Voor meer informatie: <a href='http://www.eekboek.nl'>http://www.eekboek.nl/</a></p>\n";

    $self->{p_html}->SetPage($info);

}

package EB::Wx::Tools::AboutDialog::HtmlWindow;

use strict;
use Wx::Html;
use base qw(Wx::HtmlWindow);

sub OnLinkClicked {
    my ($self, $link ) = @_;

    Wx::LaunchDefaultBrowser($link->GetHref);

}

1;
