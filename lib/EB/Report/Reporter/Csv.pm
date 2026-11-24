#! perl

# Csv.pm -- Reporter backend for CSV and JSON reports.
# Author          : Johan Vromans
# Created On      : Thu Jan  5 18:47:37 2006
# Last Modified By: Johan Vromans
# Last Modified On: Wed Jun 17 13:33:20 2026
# Update Count    : 32
# Status          : Unknown, Use with caution!

package main;

our $cfg;
our $dbh;

package EB::Report::Reporter::Csv;

use strict;
use warnings;

use EB;

use base qw(EB::Report::Reporter);

################ API ################

my $pfx;
my $output;

sub start {
    my ($self, @args) = @_;
    $pfx = $ENV{EEKBOEK_JSON} ? "json" : "csv";
    $self->SUPER::start(@args);
    return unless $pfx eq "json";
    require JSON::PP;
    $output = { count => 0, items => [] };
}

sub finish {
    my ($self) = @_;
    $self->SUPER::finish();
    if ( $pfx eq "json" ) {
	$output->{count} = scalar( @{$output->{items}} );
	my $pp = JSON::PP->new->utf8->pretty;
	print {$self->{fh}} ($pp->encode($output));
    }
    close($self->{fh});
}

my $sep;

sub add {
    goto \&{"add_$pfx"};
}

sub add_csv {
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

sub add_json {
    my ($self, $data) = @_;

    my $style = delete($data->{_style});

    $self->SUPER::add($data);

    return unless %$data;

    $self->_checkhdr;

    push( @{$output->{items}}, { %$data } );
}

################ Pseudo-Internal (used by Base class) ################

sub header {
    goto \&{"header_$pfx"};
}

sub header_csv {
    my ($self) = @_;
    if ( grep { $_->{title} =~ /\S/ } @{$self->{_fields}} ) {
	print {$self->{fh}} (join($sep,
				  map { _csv($_->{title}||"") }
				  @{$self->{_fields}}), "\n");
    }
}

sub header_json {
}

################ Internal methods ################

sub _csv {
    my ($value) = @_;
    # Quotes must be doubled.
    $value =~ s/"/""/g;
    # Quote if anything non-simple.
    $value = '"' . $value . '"'
      if $value =~ /\s|\Q$sep\E|"/
	|| $value !~ /^[+-]?\d+([.,]\d+)?/;

    return $value;
}

1;
