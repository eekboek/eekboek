#! perl

package EB::Wx::UI::GridPanel::AmtInput;

use Wx qw(wxDefaultPosition wxDefaultSize);
use base qw(EB::Wx::UI::AmountCtrl);
use strict;
use EB::Format;

sub new {
    my ($class, $parent, $arg) = @_;
    $class = ref($class) || $class;
    $arg = 0 unless defined $arg;
    my $self = $class->SUPER::new($parent, -1, $arg,
				  wxDefaultPosition, wxDefaultSize, 0);
    $self->setvalue($self->{committed_value} = $arg);
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
    $self->value != $self->{committed_value};
}

sub registerchangecallback {
    my ($self, $cb) = @_;
    Wx::Event::EVT_PL_AMOUNT($self->GetParent, $self->GetId, $cb);
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

