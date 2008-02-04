#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grid.pm,v 1.1 2008/02/04 23:08:15 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Wed Sep 14 15:23:10 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Apr 15 10:52:38 2006
# Update Count    : 26
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Report::BTWAangifte::Grid;

use strict;
use warnings;

use EB::Globals;
use EB::Format;
use Wx qw(wxBLUE wxRED wxALIGN_LEFT wxALIGN_RIGHT wxALIGN_CENTER
	  wxDEFAULT wxNORMAL wxBOLD wxOK wxICON_WARNING);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = { @_ };
    bless $self, $class;

    my $gr = $self->{grid};
    $gr->DeleteRows(0, $gr->GetNumberRows);
    $gr->SetDefaultCellAlignment(wxALIGN_LEFT, wxALIGN_CENTER);
    $gr->EnableEditing(0);
    $gr->BeginBatch;

    $self;
}

sub finish {
    my ($self, $notice) = @_;
    my $gr = $self->{grid};

    $gr->EndBatch;

    if ( $notice ) {
	Wx::MessageBox($notice, "Opmerking", wxOK|wxICON_WARNING);
    }

    $self->resize;
}

sub resize {
    my ($self) = @_;
    my $gr = $self->{grid};

    # Calculate minimal fit.
    $gr->AutoSizeColumns(1);

    # Get the total minimal width.
    my $w = 0;
    my @w;
    my $cols = $gr->GetNumberCols;
    for ( 0 .. $cols-1 ) {
	push(@w, $gr->GetColSize($_));
	$w += $w[-1];
    }

    # Get available width.
    my $width = ($gr->GetSizeWH)[0];
    $width -= 20;			# scrollbar

    # Scale columns if possible.
    if ( $w < $width ) {
	my $r = $width / $w;
	for ( 0 .. $cols-1 ) {
	    $gr->SetColSize($_, int($r*$w[$_]));
	}
    }
}

sub start {
    my ($self, $text) = @_;
}

sub addline {
    my ($self, $ctl, $tag0, $tag1, $sub, $amt) = @_;
    my $gr = $self->{grid};

    $ctl ||= "";

    my $row = $gr->GetNumberRows;
    $gr->AppendRows(1);
    my $col = 0;
    $gr->SetCellValue($row, $col, $tag0);
    $col++;
    $gr->SetCellValue($row, $col, $tag1||"");
    $col++;
    $gr->SetCellValue($row, $col, defined($sub) ? $sub : "");
    $gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
    $col++;
    $gr->SetCellValue($row, $col, defined($amt) ? $amt : "");
    $gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);

    if ( $ctl eq 'H1' ) {
	foreach ( 0..$col ) {
	    $gr->SetCellTextColour($row, $_, wxRED);
	    $gr->SetRowSize($row, 32);
	    $gr->SetCellFont($row, $_, Wx::Font->new(14, wxDEFAULT, wxNORMAL, wxBOLD, 0, ""));
	}
	$gr->SetCellOverflow($row, 0, 1);
	$gr->SetCellSize($row, 0, 1, 4)
	  if $gr->can("SetCellSize");
    }
    elsif ( $ctl eq 'H2' ) {
	foreach ( 0..$col ) {
	    $gr->SetCellTextColour($row, $_, wxBLUE);
	    $gr->SetCellFont($row, $_, Wx::Font->new(12, wxDEFAULT, wxNORMAL, wxBOLD, 0, ""));
	}
    }
    elsif ( $ctl eq 'X' ) {
	foreach ( 0..$col ) {
	    $gr->SetCellTextColour($row, $_, wxRED);
	}
    }
}
