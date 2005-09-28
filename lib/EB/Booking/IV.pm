#!/usr/bin/perl -w
my $RCS_Id = '$Id: IV.pm,v 1.23 2005/09/28 20:58:54 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::IV;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 28 22:58:50 2005
# Update Count    : 136
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Dagboek type 1: Inkoop
# Dagboek type 2: Verkoop

use EB;
use EB::DB;
use EB::Finance;
use EB::Journal::Text;
use locale;

my $trace_updates = $ENV{EB_TRACE_UPDATES};		# for debugging

sub new {
    return bless {};
}

sub perform {
    my ($self, $args, $opts) = @_;

    my $begin = $dbh->adm("begin");
    unless ( $begin && $dbh->adm("opened") ) {
	warn("?"._T("De administratie is nog niet geopend")."\n");
	return;
    }
    if ( $dbh->adm("closed") ) {
	warn("?"._T("De administratie is gesloten en kan niet meer worden gewijzigd")."\n");
	return;
    }

    my $dagboek = $opts->{dagboek};
    my $dagboek_type = $opts->{dagboek_type};
    my $totaal = $opts->{totaal};
    if ( defined($totaal) ) {
	$totaal = amount($totaal);
	return "?".__x("Ongeldig totaal: {total}", total => $totaal) unless defined $totaal;
	#$totaal = -$totaal if $dagboek_type == DBKTYPE_INKOOP;
    }

    my $date;
    if ( $date = parse_date($args->[0], substr($dbh->adm("begin"), 0, 4)) ) {
	shift(@$args);
    }
    else {
	my @tm = localtime(time);
	$date = sprintf("%04d-%02d-%02d",
			1900 + $tm[5], 1 + $tm[4], $tm[3]);
    }

    if ( $date lt $begin ) {
	warn("?"._T("De boekingsdatum valt vóór aanvang van het boekjaar")."\n");
	return;
    }

    if ( $dbh->adm("btwbegin") && $date lt $dbh->adm("btwbegin") ) {
	warn("?"._T("De boekingsdatum valt in de periode waarover al BTW aangifte is gedaan")."\n");
	return;
    }

    my $debcode;
    my $rr;
    if ( $dagboek_type == DBKTYPE_INKOOP
	 || $dagboek_type == DBKTYPE_VERKOOP ) {
	$debcode = shift(@$args);
	$rr = $dbh->do("SELECT rel_acc_id, rel_btw_status FROM Relaties" .
		       " WHERE rel_code = ?" .
		       "  AND " . ($dagboek_type == DBKTYPE_INKOOP ? "NOT " : "") . "rel_debcrd" .
		       "  AND rel_ledger = ?",
		       $debcode, $dagboek);
	unless ( defined($rr) ) {
	    warn("?".__x("Onbekende {what}: {who}",
			 what => lc($dagboek_type == DBKTYPE_VERKOOP ? _T("Debiteur") : _T("Crediteur")),
			 who => $debcode)."\n");
	    $dbh->rollback;
	    return;
	}
    }
    else {
	warn("?".__x("Ongeldige operatie (IV) voor dagboek type {type}",
		     type => $dagboek_type)."\n");
	$dbh->rollback;
	return;
    }

    my ($rel_acc_id, $sbtw) = @$rr;

    my $nr = 1;
    my $bsk_id;
    my $gdesc;
    my $did = 0;

    while ( @$args ) {
	my ($desc, $amt, $acct) = splice(@$args, 0, 3);
	$acct ||= $rel_acc_id;
	warn(" "._T("boekstuk").": $desc $amt $acct\n")
	  if $did++ || @$args || $opts->{verbose};

	my $dc = "acc_debcrd";
	my $explicit_dc;
	if ( $acct =~ /^(\d*)([cd])/i ) {
	    warn("?"._T("De \"D\" of \"C\" toevoeging aan het rekeningnummer is hier niet toegestaan")."\n");
	    return;
#	    $acct = $1 || $rel_acc_id;
#	    $explicit_dc = $dc = lc($2) eq 'd' ? 1 : 0;
	}
	my $rr = $dbh->do("SELECT acc_desc,acc_balres,$dc,acc_btw".
			  " FROM Accounts".
			  " WHERE acc_id = ?", $acct);
	unless ( $rr ) {
	    warn("?".__x("Onbekende grootboekrekening: {acct}",
			 acct => $acct)."\n");
	    $dbh->rollback;
	    return;
	}
	my ($adesc, $balres, $debcrd, $btw_id) = @$rr;

	if ( $balres ) {
	    warn("!".__x("Grootboekrekening {acct} ({desc}) is een balansrekening",
			 acct => $acct, desc => $adesc)."\n") if 0;
	    #$dbh->rollback;
	    #return;
	}

	if ( $nr == 1 ) {
	    if ( $bsk_id = $opts->{boekstuk} ) {
		$dbh->set_sequence("bsk_nr_${dagboek}_seq", $bsk_id);
	    }
	    else {
		$bsk_id = $dbh->get_sequence("bsk_nr_${dagboek}_seq");
	    }

	    $dbh->sql_insert("Boekstukken",
			     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_paid)],
			     $bsk_id, $desc, $dagboek, $date, undef);
	    $gdesc = $desc;
	    $bsk_id = $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr");
	}

	# btw_id    btw_acc
	#   0         \N          zonder BTW, extra/verlegd
	#   0         nnnn        zonder BTW
	#   n         nnnn        normaal
	#   n         \N          extra/verlegd

	# Amount can override BTW id with @X postfix.
	($amt, $btw_id) = amount($amt, $btw_id);

	# DC Phase out -- Ignore DC status of account.
	# $amt = -$amt unless $debcrd;
#	$amt = -$amt if defined($explicit_dc) &&
#	  ($explicit_dc xor $dagboek_type == DBKTYPE_INKOOP);
	$amt = -$amt if $dagboek_type == DBKTYPE_VERKOOP;

	my $btw_acc;
	# Geen BTW voor non-EU.
	if ( $btw_id && ($sbtw == BTW_NORMAAL || $sbtw == BTW_INTRA) ) {
	    my $t = "btw_" . ($dagboek_type == DBKTYPE_INKOOP ? "i" : "v");
	    if ( $btw_id =~ /^[hl]$/i ) {
		$t .= lc($btw_id);
		$btw_id = $dbh->do("SELECT btw_id".
				   " FROM BTWTabel".
				   " WHERE btw_tariefgroep = ?".
				   " AND btw_incl",
				   lc($btw_id) eq 'h' ? BTWTYPE_HOOG : BTWTYPE_LAAG)->[0];
	    }
	    else {
		my $group = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
		$t .= ($group == BTWTYPE_HOOG ? "h" : "l");
	    }
	    $btw_acc = $dbh->std_acc($t);
	}

	$dbh->sql_insert("Boekstukregels",
			 [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
			     bsr_btw_id bsr_btw_acc bsr_type bsr_acc_id bsr_rel_code)],
			 $nr++, $date, $bsk_id, $desc, $amt,
			 $btw_id, $btw_acc, 0, $acct, $debcode);
    }

    my $ret = EB::Finance::journalise($bsk_id);
    $rr = [ @$ret ];
    shift(@$rr);
    $rr = [ sort { $a->[5] <=> $b->[5] } @$rr ];
    foreach my $r ( @$rr ) {
	my (undef, undef, undef, undef, $nr, $ac, $amt) = @$r;
	next unless $nr;
	warn("update $ac with ".numfmt($amt)."\n") if $trace_updates;
	$dbh->upd_account($ac, $amt);
    }
    my $tot = $ret->[$#{$ret}]->[6];
    $dbh->sql_exec("UPDATE Boekstukken SET bsk_amount = ? WHERE bsk_id = ?",
		   $tot, $bsk_id)->finish;

    $dbh->store_journal($ret);

    $tot = -$tot if $dagboek_type == DBKTYPE_INKOOP;
    my $fail = defined($totaal) && $tot != $totaal;
    if ( $opts->{journal} ) {
	warn("?"._T("Dit overicht is ter referentie, de boeking is niet uitgevoerd!")."\n") if $fail;
	EB::Journal::Text->new->journal({select => $bsk_id, detail => 1});
    }

    if ( $fail ) {
	$dbh->rollback;
	return "?"._T("De boeking is niet uitgevoerd!")." ".
	  __x(" Boekstuk totaal is {act} in plaats van {exp}",
	      act => numfmt($tot), exp => numfmt($totaal)) . ".";
    }
    else {
	$dbh->commit;
    }

    $bsk_id;
}

1;
