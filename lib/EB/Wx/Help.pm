#! perl

package main;

our $cfg;

package EB::Wx::Help;

use strict;
use EB;

use Wx qw(wxHF_FLATTOOLBAR wxHF_DEFAULTSTYLE);
use Wx qw(wxACCEL_CTRL wxACCEL_NORMAL wxID_CLOSE);
use Wx::Event qw(EVT_BUTTON);
use Wx::Html;
use Wx::Help;
use Wx::FS;

# very important for HTB to work
Wx::FileSystem::AddHandler( new Wx::ZipFSHandler );

sub new {
    my $class = shift;
    my $self = Wx::HtmlHelpController->new( wxHF_FLATTOOLBAR|wxHF_DEFAULTSTYLE );

    $self->GetHelpWindow;
    # For convenience: CLOSE on Ctrl-W and Esc.
    # (Doesn't work on GTK, yet).
#    $self->SetAcceleratorTable
 #     (Wx::AcceleratorTable->new
  #     ( [wxACCEL_CTRL, ord 'w', wxID_CLOSE],
#	 [wxACCEL_NORMAL, 27, wxID_CLOSE],
 #      ));

    return bless \$self, $class;
}

sub show_html_help {
    my ($self) = @_;

    if ( my $htb_file = findlib( "docs.htb", "help" ) ) {
	$$self->AddBook( $htb_file, 1 );
	$$self->DisplayContents;
    }
    else {
	::info( _T("No help available for this language"),
	        _T("Sorry") );
    }
}

1;
