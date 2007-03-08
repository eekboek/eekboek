package EB::Wx::UI::GridPanel::AccInput;

use Wx qw(:allclasses wxDefaultPosition wxDefaultSize);
use base qw(EB::Wx::UI::AccInput);
use strict;

sub new {
    my ($class, $parent, $arg) = @_;
    $class = ref($class) || $class;
    $arg ||= 0;
    my $self = $class->SUPER::new($parent, -1, "", wxDefaultPosition,
				  wxDefaultSize, 0, );
    $self->setvalue($arg) if $arg;
    $self->{committed_value} = $arg;
    $self;
}

sub value {
    my ($self) = @_;
    return $self->GetValue;
    my $v = $self->GetValue;
    return 0 unless $v;
    (split(' ', $v))[0];
}

sub setvalue {
    my ($self, $value) = @_;
    $self->SetValue($value); return;
    my $pat = qr/$value/;
    foreach ( @{$self->{accts}} ) {
	next unless /^$pat\s/;
	$self->SetValue($_);
	last;
    }
}

sub changed {
    my ($self) = @_;
    $self->{committed_value} != $self->value;
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


