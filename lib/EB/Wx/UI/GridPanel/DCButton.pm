package EB::Wx::UI::GridPanel::DCButton;

use Wx qw(:allclasses wxDefaultPosition wxDefaultSize wxBITMAP_TYPE_PNG);
use base qw(Wx::BitmapButton);
use strict;

my $bm_debet;
my $bm_credit;

sub new {
    my ($class, $parent, $arg) = @_;
    $class = ref($class) || $class;
    $arg ||= 0;

    $bm_debet  ||= Wx::Bitmap->new("debet.png",  wxBITMAP_TYPE_PNG);
    $bm_credit ||= Wx::Bitmap->new("credit.png", wxBITMAP_TYPE_PNG);

    my $self = $class->SUPER::new($parent, -1,
				  $arg ? $bm_debet : $bm_credit);
    $self->{state} = $self->{committed_value} = $arg;
    $self;
}

sub value {
    my ($self) = @_;
    $self->{state};
}

sub setvalue {
    my ($self, $value) = @_;
    $self->flip_button($value);
}

sub changed {
    my ($self) = @_;
    $self->{state} xor $self->{committed_value};
}

sub registerchangecallback {
    my ($self, $cb) = @_;
    Wx::Event::EVT_BUTTON($self->GetParent, $self->GetId,
			  sub {
			      $_[1]->GetEventObject->flip_button && $cb->(@_);
			  });
}

sub flip_button {
    my ($self, $state) = @_;
    my $changed = 0;
    $state = !$self->{state} unless defined $state;
    $changed++ if ($self->{state} xor $state);
    $self->{state} = $state;
    $self->SetBitmapLabel($state ? $bm_debet : $bm_credit);
    $changed;
}

sub commit {
    my ($self) = @_;
    $self->{committed_value} = $self->{state};
    goto &reset;
}

sub reset {
    my ($self) = @_;
    $self->flip_button($self->{committed_value});
}

1;

