#!/usr/bin/perl -w
my $RCS_Id = '$Id: Grid.pm,v 1.1 2008/02/04 23:08:15 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Mon Aug  8 21:47:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Apr 15 10:52:50 2006
# Update Count    : 64
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Report::Balres::Grid;

use strict;
use warnings;

use EB::Globals;
use EB::Format;
use Wx qw(wxBLUE wxRED wxALIGN_LEFT wxALIGN_RIGHT wxALIGN_CENTER
	  wxDEFAULT wxNORMAL wxBOLD);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = { @_ };
    bless $self, $class;

    my $gr = $self->{grid};
    $gr->DeleteRows(0, $gr->GetNumberRows);

    my $col = 0;
    $gr->SetColLabelValue($col++, "Nr");

    if ( $self->{detail} < 0 ) {
	$gr->SetColLabelValue($col, "Grootboekrekening");
    }
    elsif ( $self->{detail} == 0 ) {
	$gr->SetColLabelValue($col, "Verdichting");
    }
    else {
	$gr->SetColLabelValue($col, "Verdichting/Grootboekrekening");
    }

    $col++;
    $gr->SetColLabelValue($col++, "Debet");
    $gr->SetColLabelValue($col++, "Credit");

    if ( $self->{saldi} ) {
	$gr->SetColLabelValue($col++, "Saldo Debet");
	$gr->SetColLabelValue($col++, "Saldo Credit");
    }

    $gr->EnableEditing(0);

    $self;
}

sub finish {
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

sub addline {
    my ($self, $type, $acc, $desc, $deb, $crd, $sdeb, $scrd) = @_;
    my $gr = $self->{grid};
    if ( $type eq 'H' ) {
#	print($desc, "\n\n") if $desc;
	return;
    }
    if ( $type eq 'T' ) {
#	print($self->{line});
    }
    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd, $sdeb, $scrd ) {
	$_ = $_ ? numfmt($_) : '';
    }
    if ( $type =~ /^D(\d+)/ ) {
	$desc = ("  " x $1) . $desc;
    }
    elsif ( $type =~ /^[HT](\d+)/ ) {
	$desc = ("  " x ($1-1)) . $desc;
    }
    my $row = $gr->GetNumberRows;
    $gr->AppendRows(1);
    my $col = 0;
    $gr->SetCellValue($row, $col, $acc);
    $gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
    $col++;
    $gr->SetCellValue($row, $col, $desc);
    $gr->SetCellAlignment($row, $col, wxALIGN_LEFT, wxALIGN_CENTER);
    $col++;
    $gr->SetCellValue($row, $col, $deb);
    $gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
    $col++;
    $gr->SetCellValue($row, $col, $crd);
    $gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);

    if ( $self->{saldi} ) {
	$col++;
	$gr->SetCellValue($row, $col, $sdeb);
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
	$col++;
	$gr->SetCellValue($row, $col, $scrd);
	$gr->SetCellAlignment($row, $col, wxALIGN_RIGHT, wxALIGN_CENTER);
    }

    if ( $type eq "H1" ) {
	foreach ( 0..$col ) {
	    $gr->SetCellTextColour($row, $_, wxRED);
	    $gr->SetRowSize($row, 32);
	    $gr->SetCellFont($row, $_, Wx::Font->new(14, wxDEFAULT, wxNORMAL, wxBOLD, 0, ""));
	}

    }
    elsif ( $type eq "T1" ) {
	foreach ( 0..$col ) {
	    $gr->SetCellTextColour($row, $_, wxBLUE);
	    $gr->SetCellFont($row, $_, Wx::Font->new(12, wxDEFAULT, wxNORMAL, wxBOLD, 0, ""));
	}

    }
    elsif ( $type =~ /^T/ ) {
	$gr->SetCellTextColour($row, $_, wxBLUE) for 0..$col;
    }
    elsif ( $type =~ /^H/ ) {
	$gr->SetCellTextColour($row, $_, wxRED) for 0..$col;
    }

#    print("\n") if $type =~ /^T(\d+)$/ && $1 <= $self->{detail};
}
