#!/usr/bin/perl

use strict;

use Wx;
use EB::Globals;

package main;

our $config;

package AccTreeCtrl;

use strict;
use base qw(Wx::TreeCtrl);

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my $root = $self->AddRoot("Gegevens", -1, -1);

#    foreach ( qw(Dagboek Grootboek Relatie BTW Land) ) {
    foreach ( qw(Balans Resultaat) ) {
	my $handler = $_ . "Handler";
	my $text = $handler->description;
	my $item = $self->AppendItem($root, $text, -1, -1);
	$handler->populate($self, $item);
	$self->Expand($item) if $config->expand->{$text};
    }

    use Wx::Event qw(EVT_TREE_SEL_CHANGED EVT_TREE_ITEM_ACTIVATED
		     EVT_TREE_ITEM_EXPANDED EVT_TREE_ITEM_COLLAPSED);
    EVT_TREE_SEL_CHANGED   ($self, $self, \&OnSelChange);
    EVT_TREE_ITEM_EXPANDED ($self, $self, \&OnExpand);
    EVT_TREE_ITEM_COLLAPSED($self, $self, \&OnCollapse);
    EVT_TREE_ITEM_ACTIVATED($self, $self, \&OnActivate);

    $self;
}

sub OnSelChange {
    my ($self, $event) = @_;
    my $item = $event->GetItem;
    my $data = $self->GetPlData($item);
    return unless $data && ref($data);
    return unless UNIVERSAL::can($data, "select");
    $data->select($self, $event);
}

sub OnActivate {
    my ($self, $event) = @_;
    my $item = $event->GetItem;
    my $data = $self->GetPlData($item);
    return unless $data && ref($data);
    return unless UNIVERSAL::can($data, "activate");
    $data->activate($self, $event);
}

sub OnExpand {
    my ($self, $event) = @_;
    my $item = $event->GetItem;
    my $text = $self->GetItemText($item);
    $config->expand->{$text} = 1;
}

sub OnCollapse {
    my ($self, $event) = @_;
    my $item = $event->GetItem;
    my $text = $self->GetItemText($item);
    $config->expand->{$text} = 0;
}

package StandardHandler;

use strict;

sub new {
    my ($class, $rr) = @_;
    $class = ref($class) || $class;
    bless [@$rr], $class;
}

sub select {
    my ($self, $ctrl, $event) = @_;
    print STDERR ("SEL: ", $self->[1], "\n");
}

sub activate {
    my ($self, $ctrl, $event) = @_;
    print STDERR ("ACT: ", @_, "\n");
}

package GrootboekHandler;

use strict;
use base qw(StandardHandler);

sub description { "Grootboekrekeningen" }

sub populate {
    my ($self, $ctrl, $parent, $id) = @_;
#    use Wx qw(wxBLACK wxBLUE);

    my $sth = $::dbh->sql_exec("SELECT vdi_id,vdi_desc FROM Verdichtingen".
			       " WHERE vdi_struct ".
			       (defined($id) ? " = $id" : "IS NULL").
			       " AND " .($self->type eq "balans" ? "" : "NOT") . " vdi_balres");

    my $rr;
    if ( $sth->rows ) {
	while ( $rr = $sth->fetchrow_arrayref ) {
	    my $text = "$rr->[0]   $rr->[1]";
	    my $item = $ctrl->AppendItem($parent, $text, -1, -1,
					 Wx::TreeItemData->new(GrootboekHandler->new([@$rr,0])));
	    $self->populate($ctrl, $item, $rr->[0]);
	    $ctrl->Expand($item) if $config->expand->{$text};
	}
    }
    else {
	$sth->finish;
	$sth = $::dbh->sql_exec("SELECT acc_id,acc_desc FROM Accounts".
				" WHERE acc_struct = $id");

	while ( $rr = $sth->fetchrow_arrayref ) {
	    my $id = $rr->[0];
	    my $text = $rr->[1];
	    my $item = $ctrl->AppendItem($parent, "$id   $text", -1, -1,
					 Wx::TreeItemData->new(GrootboekHandler->new([@$rr,2])));
	}
    }
}

sub select {
    my ($self, $ctrl, $event) = @_;
    my $item = $event->GetItem;
    my $data = $ctrl->GetPlData($item);
    ::set_status($data->[0] . "   " . $data->[1]);
}

sub activate {
    my ($self, $ctrl, $event) = @_;
    my $item = $event->GetItem;
    my $data = $ctrl->GetPlData($item);
    ::set_status($data->[0] . "   " . $data->[1]);

    if ( $data->[2] ) {
	$::app->{TOP}->set_acc($data->[0]);
    }
    else {
	$::app->{TOP}->set_vrd($data->[0]);
    }
}

package BalansHandler;

use strict;
use base qw(GrootboekHandler);

sub description { "Balansrekeningen" }

sub type { "balans" };

package ResultaatHandler;

use strict;
use base qw(GrootboekHandler);

sub description { "Resultaatrekeningen" }

sub type { "result" };

1;
