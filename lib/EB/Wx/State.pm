#! perl

# State.pm -- State persistency
# RCS Info        : $Id: State.pm,v 1.2 2009/10/14 21:14:02 jv Exp $
# Author          : Johan Vromans
# Created On      : Fri Feb 15 22:48:51 2008
# Last Modified By: Johan Vromans
# Last Modified On: Tue Oct 13 21:35:37 2009
# Update Count    : 8
# Status          : Unknown, Use with caution!

package main;

our $state;

package EB::Wx::State;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.2 $ =~ /(\d+)/g;

use strict;
use warnings;
use Data::Dumper;
use Carp;

sub new {
    my ($pkg) = @_;
    bless { state => {} }, $pkg;
}

sub set {
    my ($self, $key, $value) = @_;
    $self->{state}->{$key} = $value;
}

sub get {
    my ($self, $key) = @_;
    $self->{state}->{$key};
}

sub newval {
    my ($self, $key, $value) = @_;
    $self->{state}->{$key} = $value;
}

sub load {
    my ($self, $file) = @_;
    my $state;
    open(my $fh, '<:encoding(utf-8)', $file)
      or croak("Loading state: $file: $!");
    my $data = <$fh>;
    croak("Invalid state file: $file")
      unless $data =~ /^# EekBoek Wx State 1.00/;
    local $/;
    $data = <$fh>;
    close($fh);
    eval $data;
    croak("Invalid state data: $file\n$@")
      if $@;
    $self->{state} = $state;
    $self->{file} = $file;
}

sub store {
    my ($self, $file) = @_;
    $file = $self->{file} unless defined $file;
    open(my $fh, '>:encoding(utf-8)', $file)
      or carp("Saving state: $file: $!");
    print { $fh } ("# EekBoek Wx State 1.00 -- DO NOT EDIT / NIET WIJZIGEN!\n\n");
    local $Data::Dumper::Purity = 1;
    print { $fh } Data::Dumper->Dump([$self->{state}], ['state']);
    close($fh);
}

our $AUTOLOAD;
sub AUTOLOAD {
    my ($self) = @_;
    my $key = $AUTOLOAD;

    # Remove the leading package name.
    $key =~ s/.*:://;

    # Ignore destructor.
    return if $key eq 'DESTROY';

    if ( @_ > 1 ) {
	$self->{state}->{$key} = $_[1];
    }
    else {
	$self->{state}->{$key};
    }
}

1;