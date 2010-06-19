#! perl

package main;

our $dbh;
our $state;
our $app;

package EB::Wx::UI::VdiInput;

use Wx qw(wxDefaultPosition wxDefaultSize wxID_OK);
use base qw(Wx::Choice);

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

    my @vdimap;
    my %vdimap;
    my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct".
			     " FROM Verdichtingen".
			     " WHERE NOT vdi_struct IS NULL".
			     " ORDER BY vdi_id");

    while ( my $rr = $sth->fetch ) {
	$vdimap{$rr->[0]} = @vdimap;
	push(@vdimap, [ @$rr ]);
    }

    $list = [ map { sprintf("%d  %s", $_->[0], $_->[1]) } @vdimap ]
      unless ref($list) eq 'ARRAY' && scalar(@$list) > 0;

    $self = $self->SUPER::new($parent, $id, $pos, $size, $list);

    $self->{_vdi_seq_to_data} = \@vdimap;
    $self->{_vdi_code_to_seq} = \%vdimap;

    $self;
}

# Set/GetSelection deal with the ordinal values.

# Set/GetValue deal with the logical IDs.

sub GetValue {
    my ($self) = @_;
    $self->{_vdi_seq_to_data}->[$self->GetSelection]->[0];
}

sub SetValue {
    my ($self, $value) = @_;
    $self->SetSelection($self->{_vdi_code_to_seq}->{$value});
}

# For convenience, provide the rest of the info as well.

sub GetDescription {
    my ($self) = @_;
    $self->{_vdi_seq_to_data}->[$self->GetSelection]->[1];
}

sub GetBalRes {
    my ($self) = @_;
    $self->{_vdi_seq_to_data}->[$self->GetSelection]->[2];
}

sub GetKstOmz {
    my ($self) = @_;
    $self->{_vdi_seq_to_data}->[$self->GetSelection]->[3];
}

sub GetStruct {
    my ($self) = @_;
    $self->{_vdi_seq_to_data}->[$self->GetSelection]->[4];
}

1;
