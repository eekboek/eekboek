#! perl

# $Id: BTWInput.pm,v 1.1 2008/03/25 23:04:10 jv Exp $

package main;

our $dbh;
our $state;
our $app;

package EB::Wx::UI::BTWInput;

use Wx qw(wxDefaultPosition wxDefaultSize wxID_OK);
use base qw(Wx::Choice);

=begin evt_pl_btwinput

# We can use a specialized event, but it is not necessary.

use base qw(Wx::PlWindow);
use base qw(Exporter);
our @EXPORT_OK = qw(EVT_PL_BTWINPUT);
our %EXPORT_TAGS = ( 'everything'   => \@EXPORT_OK,
                     'event'        => [ qw(EVT_PL_BTWINPUT) ],
		   );

=cut

use strict;
use EB;

sub new {
    my ($self, $parent, $id, $pos, $size, $list ) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;

    my $class = ref($self) || $self;

    # Each instance holds its own table. Room for optimization.
    # Later.

    my @btwmap;
    my %btwmap;
    my $sth = $dbh->sql_exec("SELECT btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl".
			     " FROM BTWTabel".
			     " ORDER BY btw_id");

    while ( my $rr = $sth->fetch ) {
	$btwmap{$rr->[0]} = @btwmap;
	push(@btwmap, [ @$rr ]);
    }

    $list = [ map { sprintf("%d  %s", $_->[0], $_->[1]) } @btwmap ]
      unless ref($list) eq 'ARRAY' && scalar(@$list) > 0;

    $self = $self->SUPER::new($parent, $id, $pos, $size, $list);

    $self->{_btw_seq_to_data} = \@btwmap;
    $self->{_btw_code_to_seq} = \%btwmap;

=begin evt_pl_btwinput

    Wx::Event::EVT_CHOICE($self, $self->GetId, \&OnChange);

=cut

    $self;
}

# Set/GetSelection deal with the ordinal values.

# Set/GetValue deal with the logical IDs.

sub GetValue {
    my ($self) = @_;
    $self->{_btw_seq_to_data}->[$self->GetSelection]->[0];
}

sub SetValue {
    my ($self, $value) = @_;
    $self->SetSelection($self->{_btw_code_to_seq}->{$value});
}

# For convenience, provide the rest of the info as well.

sub GetDescription {
    my ($self) = @_;
    $self->{_btw_seq_to_data}->[$self->GetSelection]->[1];
}

sub GetPercentage {
    my ($self) = @_;
    $self->{_btw_seq_to_data}->[$self->GetSelection]->[2];
}

sub GetGroup {
    my ($self) = @_;
    $self->{_btw_seq_to_data}->[$self->GetSelection]->[3];
}

sub IsInclusive {
    my ($self) = @_;
    $self->{_btw_seq_to_data}->[$self->GetSelection]->[4];
}

=begin evt_pl_btwinput

my $evt_change = Wx::NewEventType;

sub Wx::Event::EVT_PL_BTWINPUT($$$) {
    $_[0]->Connect($_[1], -1, $evt_change, $_[2]);
}

sub OnChange {
    my ($self, $event) = @_;
    $self->GetEventHandler->ProcessEvent
      (EB::Wx::Perl::BTWInput::Event->new($evt_change, $self->GetId));
}

package EB::Wx::Perl::BTWInput::Event;
use base qw(Wx::PlCommandEvent);

=cut

1;
