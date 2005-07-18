#!/usr/bin/perl -w

package EB::Relation;

use EB::Globals;

use strict;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    bless $self => $class;
    $self->add(@_) if @_;
    $self;
}

sub add {

    my ($self, $code, $desc, $acct, $bstate) = @_;

    # Invoeren nieuwe relatie.

    # Koppeling debiteur/crediteur op basis van debcrd van de
    # bijbehorende grootboekrekening.

    # Koppeling met dagboek op basis van het laagstgenummerde
    # inkoop/verkoop dagboek.

    my $rr = $::dbh->do("SELECT acc_desc,acc_balres,acc_debcrd".
			" FROM Accounts".
			" WHERE acc_id = ?", $acct);
    unless ( $rr ) {
	warn("?Onbekende grootboekrekening: $acct\n");
	return;
    }

    my ($adesc, $balres, $debcrd) = @$rr;
    if ( $balres ) {
	warn("?Grootboekrekening $acct ($adesc) is een balansrekening\n");
	return;
    }

    $debcrd = 1 - $debcrd;
    my $sth = $::dbh->sql_exec("SELECT dbk_id".
			       " FROM Dagboeken".
			       " WHERE dbk_type = ?".
			       " ORDER BY dbk_id",
			       $debcrd ? DBKTYPE_VERKOOP : DBKTYPE_INKOOP);
    $rr = $sth->fetchrow_arrayref;
    $sth->finish;

    $::dbh->sql_insert("Relaties",
		       [qw(rel_code rel_desc rel_debcrd rel_btw_status rel_ledger rel_acc_id)],
		       $code, $desc, $debcrd, $bstate || 0, $rr->[0], $acct);

    $::dbh->commit;
    ($debcrd ? "Debiteur" : "Crediteur") . " " . $code;
}

1;
