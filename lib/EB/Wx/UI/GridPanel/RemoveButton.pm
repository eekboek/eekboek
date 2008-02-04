#! perl

# $Id: RemoveButton.pm,v 1.3 2008/02/04 23:25:49 jv Exp $

package EB::Wx::UI::GridPanel::RemoveButton;

use Wx qw(:everything wxDefaultPosition wxDefaultSize wxBITMAP_TYPE_PNG);
use base qw(Wx::BitmapButton);
use strict;

my $bm_edit_remove;
my $bm_edit_trash;

sub new {
    my ($class, $parent, $arg) = @_;
    $class = ref($class) || $class;
    $arg = 1 unless defined($arg);

    $bm_edit_trash  ||= Wx::Bitmap->new("edittrash.png", wxBITMAP_TYPE_PNG);
    $bm_edit_remove ||= Wx::Bitmap->new("edit_remove.png", wxBITMAP_TYPE_PNG);

    my $self = $class->SUPER::new($parent, -1,
				  $arg ? $bm_edit_remove : $bm_edit_trash);
    $self->{state} = $self->{committed_value} = $arg;
    $self;
}

sub value {
    my ($self) = @_;
    $self->{state};
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
    $self->SetBitmapLabel($state ? $bm_edit_remove : $bm_edit_trash);
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

