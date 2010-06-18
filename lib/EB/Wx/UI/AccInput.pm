#! perl

# AccInput.pm -- 
# Author          : Johan Vromans
# Created On      : Tue Aug 16 21:21:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Jun 19 00:51:49 2010
# Update Count    : 102
# Status          : Unknown, Use with caution!
#! perl

package main;

our $dbh;

package EB::Wx::UI::AccInput;

use Wx qw(wxDefaultPosition wxDefaultSize wxID_OK);
use base qw(EB::Wx::UI::ListInput);
use strict;

sub new {
    my ($self, $parent, $id, $title, $pos, $size, $style ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $title  = ""                 unless defined $title;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;
    $style  = 0			 unless defined $style;

    # Select the list of accounts, depending on the class.
    my $class = ref($self) || $self;
    my $accts = $class =~ /\bBalAccInput$/ ? $dbh->accts("acc_balres")
      : $class =~ /\bResAccInput$/ ? $dbh->accts("not acc_balres")
	: $dbh->accts;
    $accts = [ map { $_ . "   " . $accts->{$_} } sort { $a <=> $b } keys %$accts ];

    $self = $self->SUPER::new($parent, -1, "", $pos, $size, 0, $accts);
    $self;
}

1;
