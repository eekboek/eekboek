#! perl

package main;

our $cfg;
our $dbh;

package EB::Report::DebcrdList;

# Author          : Johan Vromans
# Created On      : Tue Nov  1 13:48:06 2011
# Last Modified By: Johan Vromans
# Last Modified On: Tue Nov  1 14:47:55 2011
# Update Count    : 12
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::Format;
use EB::Report::GenBase;

################ Subroutines ################

sub new {
    return bless {};
}

sub debiteuren {
    my ($self, $args, $opts) = @_;
    $self->_perform($args, $opts, 1);
}

sub crediteuren {
    my ($self, $args, $opts) = @_;
    $self->_perform($args, $opts, 0);
}

sub _perform {
    my ($self, $args, $opts, $debcrd) = @_;

    if ( $args ) {
	$args = join("|", map { quotemeta($_) } @$args);
    }

    $opts->{STYLE} = "deblist";
    $opts->{LAYOUT} =
      [ { name  => "code",
	  title => $debcrd ? _T("Debiteur") : _T("Crediteur"),
	  width => 10 },
	{ name  => "desc",   title => _T("Omschrijving"), width => 40 },
	{ name  => "ledger", title => _T("Dagboek"),      width => 10 },
	{ name  => "btw",    title => _T("BTW"),          width => 10  },
	{ name  => "acct",   title => _T("RekNr"),        width => 6, align => ">" },
      ];

    my $rep = EB::Report::GenBase->backend($self, { %$opts, debcrd => $debcrd });

    my $sth;
    my @rels;
    $sth = $dbh->sql_exec("SELECT rel_code, rel_desc, rel_btw_status, dbk_desc, rel_acc_id".
			  " FROM Relaties, Dagboeken".
			  " WHERE ". ($debcrd ? "" : "NOT ") . "rel_debcrd".
			  " AND rel_ledger = dbk_id".
			  " ORDER BY rel_code");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	next if $args && $rr->[0] !~ /^$args/i;
	push( @rels, [@$rr] );
    }
    $sth->finish;

    return "!"._T("Geen relaties gevonden") unless @rels;

    $rep->start($debcrd ? _T("Debiteurenlijst")
	                : _T("Crediteurenlijst"), " ");

    foreach my $rel ( @rels ) {

	$rep->add({ code   => $rel->[0],
		    desc   => $rel->[1],
		    btw    => BTWTYPES()->[$rel->[2]],
		    ledger => $rel->[3],
		    acct   => $rel->[4],
		    _style => $debcrd ? "deb" : "crd",
		  });
    }

    $rep->finish;
    return;
}

package EB::Report::DebcrdList::Text;

use EB;
use base qw(EB::Report::Reporter::Text);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

# Style mods.

sub style {
    my ($self, $row, $cell) = @_;

    my $stylesheet = {
    };

    $cell = "_style" unless defined($cell);
    return $stylesheet->{$row}->{$cell};
}

package EB::Report::DebcrdList::Html;

use EB;
use base qw(EB::Report::Reporter::Html);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

package EB::Report::DebcrdList::Csv;

use EB;
use base qw(EB::Report::Reporter::Csv);

sub new {
    my ($class, $opts) = @_;
    $class->SUPER::new($opts->{STYLE}, $opts->{LAYOUT});
}

1;
