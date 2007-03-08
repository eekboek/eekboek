# GridPanel.pm -- 
# RCS Info        : $Id: GridPanel.pm,v 1.2 2007/03/08 18:14:59 jv Exp $
# Author          : Johan Vromans
# Created On      : Wed Aug 24 17:40:46 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Mar  5 17:57:39 2007
# Update Count    : 296
# Status          : Unknown, Use with caution!

use Wx 0.15 qw[:allclasses];
use strict;

package EB::Wx::UI::GridPanel;

use Wx qw[:everything];
use base qw(Wx::Panel);
use strict;
use Carp;
use EB;

use EB::Wx::UI::GridPanel::RemoveButton;

################ API: new ################
#
# Constructor.
# This is fully compliant with wxPanel so you can use tools like
# wxGlade.

sub new {
    my ($self, $parent, $id, $pos, $size, $style, $name) = @_;
    $parent = undef              unless defined $parent;
    $id     = -1                 unless defined $id;
    $pos    = wxDefaultPosition  unless defined $pos;
    $size   = wxDefaultSize      unless defined $size;
    $name   = ""                 unless defined $name;

    $style = wxTAB_TRAVERSAL unless defined $style;

    $self = $self->SUPER::new($parent, $id, $pos, $size, $style, $name);

    $self->{panel} = Wx::ScrolledWindow->new($self, -1,
					     wxDefaultPosition, wxDefaultSize,
					     wxTAB_TRAVERSAL|wxVSCROLL);
    $self->{panel}->SetScrollRate(10, 10);

    $self->{b_apply} = Wx::Button->new($self, wxID_APPLY, "Apply");
    $self->{b_new}   = Wx::Button->new($self, wxID_NEW,   "New");
    $self->{b_reset} = Wx::Button->new($self, wxID_UNDO,  "Undo");

    $self->{b_apply}->Enable(0);
    $self->{b_new}->Enable(1);
    $self->{b_reset}->Enable(0);

    $self->{sz_buttons} = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->{sz_buttons}->Add($self->{b_apply}, 0, wxADJUST_MINSIZE, 0);
    $self->{sz_buttons}->Add($self->{b_new}, 0, wxLEFT|wxADJUST_MINSIZE, 5);
    $self->{sz_buttons}->Add(5, 1, 1, wxADJUST_MINSIZE, 0);
    $self->{sz_buttons}->Add($self->{b_reset}, 0, wxADJUST_MINSIZE, 0);

    Wx::Event::EVT_BUTTON($self, wxID_APPLY, \&OnApply);
    Wx::Event::EVT_BUTTON($self, wxID_NEW,   \&OnNew);
    Wx::Event::EVT_BUTTON($self, wxID_UNDO,  \&OnReset);

    $self;
}

################ API: create ################
#
# Creating the internal grid.
#
# The main parameter is an array ref with arguments pairs. The first
# of a pair is the label, the second is either the name of the wrapper
# class, or an array ref with the wrapper class as its first element,
# and and array ref with construction data as the second element.

sub create {
    my ($self, $cols, $vgap, $hgap) = @_;

    die(__PACKAGE__ . " columns argument must be an array ref")
      unless UNIVERSAL::isa($cols, 'ARRAY');
    die(__PACKAGE__ . " columns argument must contain columns")
      unless @$cols && !(@$cols % 2);

    $self->{cols} = @$cols / 2;
    $vgap = 0 unless defined $vgap;
    $hgap = 0 unless defined $hgap;

    if ( defined $self->{grid} ) {
	# Remove all except the first row (the labels).
	for (my $row = $self->{rows}-1; $row > 0; $row-- ) {
	    for (my $col = $self->{cols}-1; $col >= 0; $col-- ) {
		my $item = $self->item($row,$col);
		next unless $item;
		if ( $self->{grid}->Detach($item) ) {
		    $item->Destroy;
		}
		else {
		    Wx::LogMessage("GridPanel: detach failed: $row $col $item");
		}
		delete($self->{rc($row,$col)});
	    }
	    delete($self->{rx($_, $row)}) foreach qw(b d n x);
	}
    }
    else {
	$self->{grid} = Wx::FlexGridSizer->new(1, $self->{cols}, $vgap, $hgap);
	my $i = 0;
	my $flip = 0;
	foreach my $col ( @$cols ) {
	    if ( $flip ) {
		# Template.
		push(@{$self->{grid_cols}}, $col);
		$i++;
	    }
	    else {
		# Label. Abusing rx ...
		$self->{rx("l", $i)} = Wx::StaticText->new($self->{panel}, -1, $col, wxDefaultPosition, wxDefaultSize, );
		$self->{grid}->Add($self->{rx("l", $i)}, 0, wxLEFT|wxEXPAND|wxADJUST_MINSIZE, 5);
	    }
	    $flip = !$flip;
	}
	$self->{panel}->SetSizer($self->{grid});
	$self->{sz_main} = Wx::BoxSizer->new(wxVERTICAL);
	$self->{sz_main}->Add($self->{panel},      1, wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 0);
	$self->{sz_main}->Add($self->{sz_buttons}, 0, wxTOP|wxEXPAND|wxADJUST_MINSIZE|wxFIXED_MINSIZE, 10);
	$self->SetSizer($self->{sz_main});
	$self->SetAutoLayout(1);
	$self->{sz_main}->SetSizeHints($self);
	Wx::Event::EVT_IDLE($self, \&OnIdle);
    }

    $self->{grid}->SetRows($self->{rows} = 1);
    $self->Layout();
}

################ API: addgrowablecol ################
#
# See wxFlexGridSizer for details.

sub addgrowablecol {
    my ($self) = shift;
    $self->{grid}->AddGrowableCol(@_);
}

################ API: registerapplycb ################
#
# Register the callback for the "Apply" operation.
#
# The callback should return true if the changes are applied successfully.
#
# The callback gets an array refence passed.
#
#  ref -> [ [ <action>, <new contents>, <user data> ], ...]
#
#  action: 0 -> new row
#         -1 -> deleted row
#       else -> changed row, 1 bit per changed column

#### TODO: Use event. See Wx::Perl::VirtualTreeCtrl on CPAN for an example.
#### DONE: Cannot use event -- need return value.

sub registerapplycb {
    my ($self, $cb) = @_;
    $self->{applycb} = $cb;
}

################ API: append ################
#
# Append a new row to the grid.
#
# If there are more values supplied than required, the remaining
# values will be stored and passed back when calling the apply
# callback (for identification or so).

sub append {
    my ($self, @values) = @_;
    $self->new_or_append(0, @values);
}

################ API: changed ################
#
# Returns true if any of the items in the grid have changed.

sub changed {
    my ($self) = @_;
    foreach my $row ( 1 .. $self->{rows}-1 ) {
	next unless $self->exists($row);
	return 1 if $self->is_deleted($row) || $self->is_new($row);
	foreach my $col ( 0 .. $self->{cols}-1 ) {
	    my $item = $self->item($row, $col);
	    warn("changed: UNDEFINED ITEM @ $row $col\n") unless $item;
	    next unless $item->changed;
	    return 1;
	}
    }
    undef;
}

################ API: enable ################
#
# Enable/disable columns.

sub enable {
    my ($self, @values) = @_;
    my $row = $self->{rows} - 1;
    foreach my $col ( 0 .. $self->{cols}-1 ) {
	$self->item($row, $col)->Enable($values[$col]);
    }
}

################ Low level services ################

sub rc {
    sprintf("r_%02d_c_%02d", @_);
}

sub rx {
    sprintf("%s_%02d", @_);
}

sub item : lvalue {
    my ($self, $row, $col) = @_;
    $self->{rc($row, $col)};
}

sub rembut : lvalue {
    my ($self, $row) = @_;
    $self->{rx("b", $row)};
}

sub exists {
    my ($self, $row) = @_;
    defined($self->{rx("n", $row)});
}

sub is_new : lvalue {
    my ($self, $row) = @_;
    $self->{rx("n", $row)};
}

sub is_deleted : lvalue {
    my ($self, $row) = @_;
    $self->{rx("x", $row)};
}

sub data : lvalue {
    my ($self, $row) = @_;
    $self->{rx("d", $row)};
}

################ Services ################

sub reset_changes {
    my ($self) = @_;
    foreach my $row ( 1 .. $self->{rows}-1 ) {
	next unless $self->exists($row);
	my $item = $self->rembut($row);
	if ( $item ) { #&& $self->is_deleted($row) && !$self->is_new($row) ) {
	    $item->reset;
	    $self->OnRemoveButton($row);
	}
	foreach my $col ( 0 .. $self->{cols}-1 ) {
	    $item = $self->item($row, $col);
	    warn("reset: UNDEFINED ITEM @ $row $col\n") unless $item;
	    $item->reset;
	}
    }
}

sub perform_update {
    my ($self) = @_;
    my @actions;
    my $rows = $self->{rows};
    foreach my $row ( 1 .. $rows-1 ) {
	next unless $self->exists($row);
	my $rowchanged = 0;
	my $action = 0;
	if ( $self->is_new($row) ) {
	    $action = 0;
	    $rowchanged++ unless $self->is_deleted($row);
	}
	elsif ( $self->is_deleted($row) ) {
	    $action = -1;
	    $rowchanged++ unless $self->is_new($row);
	}
	my @act = (0);
	foreach my $col ( 0 .. $self->{cols}-1 ) {
	    my $item = $self->item($row, $col);
	    push(@act, $item->value);
	    $action |= (1 << $col), $rowchanged++ if $item && $item->changed;
	    $col++;
	}
	$act[0] = $self->is_new($row) ? 0 : $action;
	my $data = $self->data($row);
	push(@act, @$data) if $data;
	push(@actions, [@act]) if $rowchanged;
    }
    if ( $self->{applycb}->(\@actions) ) {
	foreach my $row ( 1 .. $rows-1 ) {
	    next unless $self->exists($row);
	    if ( $self->is_new($row) && !$self->is_deleted($row) ) {
		$self->is_new($row) = 0;
	    }
	}
	return 1;
    }
    undef;
}

sub expunge_rows {
    my ($self) = @_;
    foreach my $row ( 1 .. $self->{rows}-1 ) {
	next unless $self->exists($row);
	next unless $self->is_deleted($row);# && $self->is_new($row);
	delete($self->{rx($_, $row)}) foreach qw(n b d x);
	foreach my $col ( 0 .. $self->{cols}-1 ) {
	    my $item = $self->item($row, $col);
	    $self->{grid}->Detach($item) or warn("detach failed ", rc($row, $col), "\n");
	    $item->Destroy;
	    delete($self->{rc($row, $col)});
	}
    }
}

sub commit_changes {
    my ($self) = @_;
    foreach my $row ( 1 .. $self->{rows}-1 ) {
	next unless $self->exists($row);
	foreach my $col ( 0 .. $self->{cols}-1 ) {
	    $self->item($row, $col)->commit;
	}
	$self->is_new($row) = 0;
	$self->is_deleted($row) = 0;
    }
}

sub new_or_append {
    my ($self, $new, @values) = @_;
    my $r = $self->{rows}++;
    my $c = 0;
    foreach my $col ( @{$self->{grid_cols}} ) {
	my $w;
	my $f = $col;
	my @args;
	if ( UNIVERSAL::isa($col, 'ARRAY') ) {
	    ($f, @args) = @$col;
	}
	push(@args, shift(@values)) unless $new;

	if ( $f eq EB::Wx::UI::GridPanel::RemoveButton:: ) {
	    $w = $self->rembut($r) = $f->new($self->{panel}, $new);
	    #$w->SetToolTip(rx("b", $r));
	    $self->is_deleted($r) = $new;
	    $self->is_new($r) = $new;
	    $w->registerchangecallback(sub { $self->OnRemoveButton($r) });
	}
	else {
	    $w = $f->new($self->{panel}, @args);
	    #$w->SetToolTip(rc($r, $c));
	    $w->registerchangecallback(sub { $self->{_check_changed}++ });
	}
	$self->item($r, $c) = $w;
	$self->{grid}->Add($w, 0, wxEXPAND|wxADJUST_MINSIZE, 0);
	$c++;
	if ( @values ) {
	    $self->data($r) = [@values];
	}
    }

    $self->{grid}->FitInside($self->{panel});
    $self->Layout();
    $self->{_check_changed}++;
    $r;
}

################ Event handlers ################

sub OnRemoveButton {
    my ($self, $row) = @_;
    my $button = $self->rembut($row);
    $self->is_deleted($row) = $button->value;
    $self->{_check_changed}++;
}

sub OnIdle {
    my ($self) = @_;
    return unless $self->{_check_changed};
    $self->{_check_changed} = 0;
    my $ch = $self->changed;
    $self->{b_apply}->Enable($ch);
    $self->{b_reset}->Enable($ch);
}

sub OnReset {
    my ($self) = @_;

    $self->reset_changes;
    $self->expunge_rows;

    $self->{grid}->FitInside($self->{panel});
    $self->Layout;
    $self->{_check_changed}++;
}

sub OnApply {
    my ($self) = @_;

    if ( $self->perform_update ) {
	$self->expunge_rows;
	$self->commit_changes;
    }

    $self->{grid}->FitInside($self->{panel});
    $self->Layout;
    $self->{_check_changed}++;
}

sub OnNew {
    my ($self) = @_;
    $self->new_or_append(1);
    $self->{panel}->Scroll(-1,9999); #### TODO
}

1;

