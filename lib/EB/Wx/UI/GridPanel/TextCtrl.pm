#! perl

# TextCtrl.pm -- 
# Author          : Johan Vromans
# Created On      : Fri Sep 16 20:31:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jun 14 22:02:59 2010
# Update Count    : 101
# Status          : Unknown, Use with caution!

package EB::Wx::UI::GridPanel::TextCtrl;

use Wx qw(wxDefaultPosition wxDefaultSize);
use base qw(Wx::TextCtrl);
use strict;

sub new {
    my ($class, $parent, $arg) = @_;
    $class = ref($class) || $class;
    $arg = "" unless defined $arg;
    my $self = $class->SUPER::new($parent, -1, $arg,
				  wxDefaultPosition, wxDefaultSize, 0);
    $self->{committed_value} = $arg;
    $self;
}

sub value {
    my ($self) = @_;
    $self->GetValue;
}

sub setvalue {
    my ($self, $value) = @_;
    $self->SetValue($value);
}

sub changed {
    my ($self) = @_;
    $self->GetValue ne $self->{committed_value};
}

sub registerchangecallback {
    my ($self, $cb) = @_;
    Wx::Event::EVT_TEXT($self->GetParent, $self->GetId, $cb);
}

sub reset {
    my ($self) = @_;
    $self->setvalue($self->{committed_value});
}

sub commit {
    my ($self) = @_;
    $self->{committed_value} = $self->value;
}

1;

