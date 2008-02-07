#! perl

# Text.pm -- Reporter backend for text reports.
# RCS Info        : $Id: Text.pm,v 1.7 2008/02/07 13:25:07 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Dec 28 13:21:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  7 14:25:04 2008
# Update Count    : 69
# Status          : Unknown, Use with caution!

package main;

our $cfg;
our $dbh;

package EB::Report::Reporter::Text;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.7 $ =~ /(\d+)/g;

use EB;

use base qw(EB::Report::Reporter);

################ API ################

sub start {
    my ($self, @args) = @_;
    $self->SUPER::start(@args);
    $self->_make_format;
    $self->{_lines} = 0;
    $self->{_page} = 0;
}

sub finish {
    my ($self) = @_;
    $self->_checkskip(1);	# cancel skips.
    $self->SUPER::finish();
    close($self->{fh});
}

sub add {
    my ($self, $data) = @_;

    my $style = delete($data->{_style});

    $self->SUPER::add($data);

    $self->_checkhdr;

    my $skip_after = 0;
    my $line_after = 0;
    my $cancel_skip = 0;
    if ( $style and my $t = $self->_getstyle($style) ) {
	$self->_skip if $t->{skip_before};
	$skip_after   = $t->{skip_after};
	$self->_line if $t->{line_before};
	$line_after   = $t->{line_after};
	$cancel_skip  = $t->{cancel_skip};
    }

    $self->_checkskip($cancel_skip);

    my @values;
    my @widths;
    my @indents;
    my $linebefore;
    my $lineafter;
    push(@values, $style||"") if $cfg->val(__PACKAGE__, "layout", 0);
    foreach my $col ( @{$self->{_fields}} ) {
	my $fname = $col->{name};
	push(@values, defined($data->{$fname}) ? $data->{$fname} : "");
	push(@widths, $col->{width});

	# Examine style mods.
	my $indent = 0;
	my $excess = 0;
	if ( $style ) {
	    if ( my $t = $self->_getstyle($style, $fname) ) {
		$indent = $t->{indent} || 0;
		if ( $t->{line_before} ) {
		    $linebefore->{$fname} =
		      ($t->{line_before} eq "1" ? "-" : $t->{line_before}) x $col->{width};
		}
		if ( $t->{line_after} ) {
		    $lineafter->{$fname} =
		      ($t->{line_after} eq "1" ? "-" : $t->{line_after}) x $col->{width};
		}
		if ( $t->{excess} ) {
		    $widths[-1] += 2;
		}
		if ($t->{truncate} ) {
		    $values[-1] = substr($values[-1], 0, $widths[-1] - $indent);
		}
	    }
	}
	push(@indents, $indent);

    }

    if ( $linebefore ) {
	$self->add($linebefore);
    }

    my @lines;
    while ( 1 ) {
	my $more = 0;
	my @v;
	foreach my $i ( 0..$#widths ) {
	    my $ind = $indents[$i];
	    my $maxw = $widths[$i] - $ind;
	    $ind = " " x $ind;
	    if ( length($values[$i]) <= $maxw ) {
		push(@v, $ind.$values[$i]);
		$values[$i] = "";
	    }
	    else {
		my $t = substr($values[$i], 0, $maxw);
		if ( substr($values[$i], $maxw, 1) eq " " ) {
		    push(@v, $ind.$t);
		    substr($values[$i], 0, length($t) + 1, "");
		}
		elsif ( $t =~ /^(.*)([ ]+)/ ) {
		    my $pre = $1;
		    push(@v, $ind.$pre);
		    substr($values[$i], 0, length($pre) + length($2), "");
		}
		else {
		    push(@v, $ind.$t);
		    substr($values[$i], 0, $maxw, "");
		}
		$more++;
	    }
	}
	my $t = sprintf($self->{_format}, @v);
	$t =~ s/ +$//;
	push(@lines, $t) if $t =~ /\S/;
	last unless $more;
    }

    if ( $self->{_lines} < @lines ) {
	$self->{_needhdr} = 1;
	$self->_checkhdr;
    }
    print {$self->{fh}} @lines;
    $self->{_lines} -= @lines;

    # Post: Lines for cells.
    if ( $lineafter ) {
	$self->add($lineafter);
    }
    # Post: Line for row.
    if ( $line_after ) {
	$self->_line;
    }
    # Post: Skip after this row.
    elsif ( $skip_after ) {
	$self->_skip;
    }
}

################ Pseudo-Internal (used by Base class) ################

sub header {
    my ($self) = @_;
    my $t = sprintf("%s\n" .
		    "%-" . ($self->{_width}-10) . "s%10s\n" .
		    "%-" . ($self->{_width}-31) . "s%31s\n" .
		    "\n" .
		    $self->{_format},
		    $self->_center($self->{_title1}, $self->{_width}),
		    $self->{_title2},
		    1 ? "" : ("Blad: " . (++$self->{_page})),
		    $self->{_title3l}, $self->{_title3r},
		    map { $_->{title} } @{$self->{_fields}});
    $t =~ s/ +$//gm;
    print {$self->{fh}} ($t);
    $self->_line;
    $self->_checkskip(1);	# cancel skips.
    $self->{_lines} = $self->{page} - 6;
}

################ Internal methods ################

sub _make_format {
    my ($self) = @_;

    my $width = 0;		# new width
    my $format = "";		# new format

    $format = "%6s  " if $cfg->val(__PACKAGE__, "layout", 0);

    foreach my $a ( @{$self->{_fields}} ) {

	# Never mind the trailing blanks -- we'll trim anyway.
	$width += $a->{width} + 2;
	if ( $a->{align} eq "<" ) {
	    $format .= "%-".
	      join(".", ($a->{width}+2) x 2) .
		"s";
	}
	else {
	    $format .= "%".
	      join(".", ($a->{width}) x 2) .
		"s  ";
	}
    }

    # Store format and width in object.
    $self->{_format} = $format . "\n";
    $self->{_width}  = $width - 2;

    # PBP: Return nothing sensible.
    return;
}

sub _checkskip {
    my ($self, $cancel) = @_;
    return if !$self->{_needskip} || $self->{_lines} <= 0;
    $self->{_lines}--, print {$self->{fh}} ("\n") unless $cancel;
    $self->{_needskip} = 0;
}

sub _line {
    my ($self) = @_;

    $self->_checkhdr;
    $self->_checkskip(1);	# cancel skips.

    print {$self->{fh}} ("-" x ($self->{_width}), "\n");
    $self->{_lines}--;
}

sub _skip {
    my ($self) = @_;

    $self->_checkhdr;
    $self->{_needskip} = 1;
}

sub _center {
    my ($self, $text, $width) = @_;
    (" " x (($width - length($text))/2)) . $text;
}

sub _expand {
    my ($self, $text) = @_;
    $text =~ s/(.)/$1 /g;
    $text =~ s/ +$//;
    $text;
}

1;
