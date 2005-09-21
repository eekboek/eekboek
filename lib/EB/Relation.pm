#!/usr/bin/perl -w

package EB::Relation;

use EB;

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

    my ($self, $code, $desc, $acct, $opts) = @_;
    my $bstate = $opts->{btw};
    my $dbk = $opts->{dagboek};

    # Invoeren nieuwe relatie.

    # Koppeling debiteur/crediteur op basis van debcrd van de
    # bijbehorende grootboekrekening.

    # Koppeling met dagboek op basis van het laagstgenummerde
    # inkoop/verkoop dagboek.

    my $dbcd = "acc_debcrd";
    if ( $acct =~ /^(\d+)([DC]$)/i) {
	$acct = $1;
	$dbcd = uc($2) eq 'D' ? 1 : 0;
    }

    my $rr = $::dbh->do("SELECT acc_desc,acc_balres,$dbcd".
			" FROM Accounts".
			" WHERE acc_id = ?", $acct);
    unless ( $rr ) {
	warn("?".__x("Onbekende grootboekrekening: {acct}", acct => $acct). "\n");
	return;
    }

    my ($adesc, $balres, $debcrd) = @$rr;
    if ( $balres ) {
	warn("?".__x("Grootboekrekening {acct} ({desc}) is een balansrekening",
		     acct => $acct, desc => $adesc)."\n");
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
    ($debcrd ? _T("Debiteur") : _T("Crediteur")) . " " . $code .
      " -> $acct ($adesc)";
}

1;
