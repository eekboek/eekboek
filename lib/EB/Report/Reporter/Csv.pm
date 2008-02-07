#! perl

# Csv.pm -- Reporter backend for CSV reports.
# RCS Info        : $Id: Csv.pm,v 1.5 2008/02/07 13:24:34 jv Exp $
# Author          : Johan Vromans
# Created On      : Thu Jan  5 18:47:37 2006
# Last Modified By: Johan Vromans
# Last Modified On: Thu Feb  7 14:24:31 2008
# Update Count    : 13
# Status          : Unknown, Use with caution!

package main;

our $cfg;
our $dbh;

package EB::Report::Reporter::Csv;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.5 $ =~ /(\d+)/g;

use EB;

use base qw(EB::Report::Reporter);

################ API ################

sub start {
    my ($self, @args) = @_;
    $self->SUPER::start(@args);
}

sub finish {
    my ($self) = @_;
    $self->SUPER::finish();
    close($self->{fh});
}

my $sep;

sub add {
    my ($self, $data) = @_;

    my $style = delete($data->{_style});

    $self->SUPER::add($data);

    return unless %$data;

    $sep = $self->{_sep} ||= $cfg->val(qw(csv separator), ",");

    $self->_checkhdr;

    my $line;

    foreach my $col ( @{$self->{_fields}} ) {
	my $fname = $col->{name};
	my $value = defined($data->{$fname}) ? _csv($data->{$fname}) : "";
	$line .= $sep if defined($line);
	$line .= $value;
    }

    print {$self->{fh}} ($line, "\n");
}

################ Pseudo-Internal (used by Base class) ################

sub header {
    my ($self) = @_;

    print {$self->{fh}} (join($sep, map { _csv($_->{title}) } @{$self->{_fields}}), "\n");
}

################ Internal methods ################

sub _csv {
    my ($value) = @_;
    # Quotes must be doubled.
    $value =~ s/"/""/g;
    # Quote if anything non-simple.
    $value = '"' . $value . '"'
      if $value =~ /\s|$sep|"/
	|| $value !~ /^[+-]?\d+([.,]\d+)?/;

    return $value;
}

1;
