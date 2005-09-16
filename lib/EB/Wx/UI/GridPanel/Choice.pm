package GridPanel::Choice;

use Wx qw(:allclasses wxDefaultPosition wxDefaultSize);
use base qw(Wx::Choice);
use strict;

sub new {
    my ($class, $parent, $ch, $val) = @_;
    $class = ref($class) || $class;
    my $self = $class->SUPER::new($parent, -1, wxDefaultPosition, wxDefaultSize, $ch);
    $self->SetSelection($self->{committed_value} = $val||0);
    $self;
}

sub value {
    my ($self) = @_;
    $self->GetSelection;
}

sub setvalue {
    my ($self, $value) = @_;
    $self->SetSelection($value);
}

sub changed {
    my ($self) = @_;
    $self->{committed_value} ne $self->value;
}

sub registerchangecallback {
    my ($self, $cb) = @_;
    Wx::Event::EVT_CHOICE($self->GetParent, $self->GetId, $cb);
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
