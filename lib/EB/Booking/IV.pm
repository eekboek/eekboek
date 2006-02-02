#!/usr/bin/perl -w
my $RCS_Id = '$Id: IV.pm,v 1.34 2006/02/02 11:31:51 jv Exp $ ';

package main;

our $cfg;
our $dbh;
our $spp;
our $config;

package EB::Booking::IV;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Jan 31 21:42:27 2006
# Update Count    : 225
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Dagboek type 1: Inkoop
# Dagboek type 2: Verkoop

use EB;
use EB::DB;
use EB::Finance;
use EB::Report::Journal;
use base qw(EB::Booking);

my $trace_updates = $cfg->val(__PACKAGE__, "trace_updates", 0);	# for debugging

sub perform {
    my ($self, $args, $opts) = @_;

    return unless $self->adm_open;

    my $dagboek = $opts->{dagboek};
    my $dagboek_type = $opts->{dagboek_type};

    unless ( $dagboek_type == DBKTYPE_INKOOP || $dagboek_type == DBKTYPE_VERKOOP) {
	warn("?".__x("Ongeldige operatie (IV) voor dagboek type {type}",
		     type => $dagboek_type)."\n");
	$dbh->rollback;
	return;
    }

    my $iv = $dagboek_type == DBKTYPE_INKOOP;
    my $totaal = $opts->{totaal};

    my $bky = $self->{bky} ||= $opts->{boekjaar} || $dbh->adm("bky");

    if ( defined($totaal) ) {
	$totaal = amount($totaal);
	return "?".__x("Ongeldig totaal: {total}", total => $totaal) unless defined $totaal;
	#$totaal = -$totaal if $iv;
    }

    my ($begin, $end);
    return unless ($begin, $end) = $self->begindate;

    my $date;
    if ( $date = parse_date($args->[0], substr($begin, 0, 4)) ) {
	shift(@$args);
    }
    else {
	return "?".__x("Onherkenbare datum: {date}",
		       date => $args->[0])."\n"
	  if ($args->[0]||"") =~ /^[[:digit:]]/;
	$date = iso8601date();
    }

    return "?"._T("Deze opdracht is onvolledig. Gebruik de \"help\" opdracht voor meer aanwijzingen.")."\n"
      unless @$args >= 3;

    return unless $self->in_bky($date, $begin, $end);

    if ( $dbh->adm("btwbegin") && $date lt $dbh->adm("btwbegin") ) {
	warn("?"._T("De boekingsdatum valt in de periode waarover al BTW aangifte is gedaan")."\n");
	return;
    }

    my $gdesc;
    my $debcode;
    my $rr;

    if ( $cfg->val(qw(general ivdesc), undef) ) {
	$gdesc  = shift(@$args);
	$debcode = shift(@$args);
	$rr = $dbh->do("SELECT rel_code, rel_acc_id, rel_btw_status FROM Relaties" .
		       " WHERE UPPER(rel_code) = ?" .
		       "  AND " . ($iv ? "NOT " : "") . "rel_debcrd" .
		       "  AND rel_ledger = ?",
		       uc($debcode), $dagboek);
	unless ( defined($rr) ) {
	    unshift(@$args, $debcode);
	    $debcode = $gdesc;
	    undef $gdesc;
	    $rr = $dbh->do("SELECT rel_code, rel_acc_id, rel_btw_status FROM Relaties" .
			   " WHERE UPPER(rel_code) = ?" .
			   "  AND " . ($iv ? "NOT " : "") . "rel_debcrd" .
			   "  AND rel_ledger = ?",
			   uc($debcode), $dagboek);
	    unless ( defined($rr) ) {
		warn("?".__x("Onbekende {what}: {who}",
			     what => lc($iv ? _T("Crediteur") : _T("Debiteur")),
			     who => $debcode)."\n");
		$dbh->rollback;
		return;
	    }
	}
    }
    else {
	$debcode = shift(@$args);
	$rr = $dbh->do("SELECT rel_code, rel_acc_id, rel_btw_status FROM Relaties" .
		       " WHERE UPPER(rel_code) = ?" .
		       "  AND " . ($iv ? "NOT " : "") . "rel_debcrd" .
		       "  AND rel_ledger = ?",
		       uc($debcode), $dagboek);
	unless ( defined($rr) ) {
	    $gdesc = $debcode;
	    $debcode = shift(@$args);
	    $rr = $dbh->do("SELECT rel_code, rel_acc_id, rel_btw_status FROM Relaties" .
			   " WHERE UPPER(rel_code) = ?" .
			   "  AND " . ($iv ? "NOT " : "") . "rel_debcrd" .
			   "  AND rel_ledger = ?",
			   uc($debcode), $dagboek);
	    unless ( defined($rr) ) {
		warn("?".__x("Onbekende {what}: {who}",
			     what => lc($iv ? _T("Crediteur") : _T("Debiteur")),
			     who => $debcode)."\n");
		$dbh->rollback;
		return;
	    }
	}
    }

    my ($rel_acc_id, $sbtw);
    ($debcode, $rel_acc_id, $sbtw) = @$rr;

    my $nr = 1;
    my $bsk_id;
    my $bsk_nr;
    my $did = 0;

    while ( @$args ) {
	return "?"._T("Deze opdracht is onvolledig. Gebruik de \"help\" opdracht voor meer aanwijzingen.")."\n"
	  unless @$args >= 2;
	my ($desc, $amt, $acct) = splice(@$args, 0, 3);
	$acct ||= $rel_acc_id;
	if ( $did++ || @$args || $opts->{verbose} ) {
	    my $t = $desc;
	    $t = '"' . $desc . '"' if $t =~ /\s/;
	    warn(" "._T("boekstuk").": $t $amt $acct\n");
	}

	my $dc = "acc_debcrd";
	my $explicit_dc;
	if ( $acct =~ /^(\d*)([cd])/i ) {
	    warn("?"._T("De \"D\" of \"C\" toevoeging aan het rekeningnummer is hier niet toegestaan")."\n");
	    return;
#	    $acct = $1 || $rel_acc_id;
#	    $explicit_dc = $dc = lc($2) eq 'd' ? 1 : 0;
	}
	elsif  ( $acct !~ /^\d+$/ ) {
	    warn("?".__x("Ongeldig grootboekrekeningnummer: {acct}", acct => $acct )."\n");
	    return;
	}
	my $rr = $dbh->do("SELECT acc_desc,acc_balres,acc_kstomz,$dc,acc_btw".
			  " FROM Accounts".
			  " WHERE acc_id = ?", $acct);
	unless ( $rr ) {
	    warn("?".__x("Onbekende grootboekrekening: {acct}",
			 acct => $acct)."\n");
	    $dbh->rollback;
	    return;
	}
	my ($adesc, $balres, $kstomz, $debcrd, $btw_id) = @$rr;

	if ( $balres ) {
	    warn("!".__x("Grootboekrekening {acct} ({desc}) is een balansrekening",
			 acct => $acct, desc => $adesc)."\n") if 0;
	    #$dbh->rollback;
	    #return;
	}
	elsif ( $kstomz ? !$iv : $iv ) {
	    warn("!".__x("Grootboekrekening {acct} ({desc}) is een {what}rekening",
			 acct => $acct, desc => $adesc,
			 what => $kstomz ? _T("kosten") : _T("omzet"),
			)."\n");
	    #$dbh->rollback;
	    #return;
	}

	if ( $nr == 1 ) {
	    $bsk_nr = $self->bsk_nr($opts);
	    $gdesc ||= $desc;
	    $dbh->sql_insert("Boekstukken",
			     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_bky)],
			     $bsk_nr, $gdesc, $dagboek, $date, $bky);
	    $bsk_id = $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr");
	}

	# btw_id    btw_acc
	#   0         \N          zonder BTW, extra/verlegd
	#   0         nnnn        zonder BTW
	#   n         nnnn        normaal
	#   n         \N          extra/verlegd

	# Amount can override BTW id with @X postfix.
	my $oamt = $amt;
	($amt, $btw_id) = amount($amt, $btw_id);
	unless ( defined($amt) ) {
	    warn("?".__x("Ongeldig bedrag: {amt}", amt => $oamt)."\n");
	    return;
	}

	$amt = -$amt unless $iv;

	my $btw_acc;
	my $t = "btw_" . ($iv ? "i" : "v");
	# Geen BTW voor non-EU.
	if ( $btw_id && ($sbtw == BTWTYPE_NORMAAL || $sbtw == BTWTYPE_INTRA) ) {
	    if ( $btw_id =~ /^[hl]$/i ) {
		$t .= lc($btw_id);
		$btw_id = $dbh->do("SELECT btw_id".
				   " FROM BTWTabel".
				   " WHERE btw_tariefgroep = ?".
				   " AND btw_incl",
				   lc($btw_id) eq 'h' ? BTWTARIEF_HOOG : BTWTARIEF_LAAG)->[0];
	    }
	    else {
		my $group = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
		$t .= ($group == BTWTARIEF_HOOG ? "h" : "l");
	    }
	    $btw_acc = $dbh->std_acc($t);
	}

	my $btwclass = 0;
	# Inkoop: alle bedragen met BTW en intra/extra bedragen zijn van belang.
	if ( $iv ) {
	    $btwclass = BTWKLASSE(1, $sbtw, 1)
	      if $btw_id || $sbtw == BTWTYPE_INTRA || $sbtw == BTWTYPE_EXTRA;
	}
	# Verkoop: alle bedragen met BTW, en alle omzetten met 0%.
	# Zo ook intra en extra.
	else {
	    $btwclass = BTWKLASSE(1, $sbtw, 0)
	      if $btw_id || !$kstomz || $sbtw == BTWTYPE_INTRA || $sbtw == BTWTYPE_EXTRA;
	}
	$dbh->sql_insert("Boekstukregels",
			 [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
			     bsr_btw_id bsr_btw_acc bsr_btw_class bsr_type bsr_acc_id bsr_rel_code)],
			 $nr++, $date, $bsk_id, $desc, $amt,
			 $btw_id, $btw_acc, $btwclass, 0, $acct, $debcode);
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
    $dbh->sql_exec("UPDATE Boekstukken SET bsk_amount = ?, bsk_open = ? WHERE bsk_id = ?",
		   $tot, $tot, $bsk_id)->finish;

    $dbh->store_journal($ret);

    $tot = -$tot if $iv;
    my $fail = defined($totaal) && $tot != $totaal;
    if ( $opts->{journal} ) {
	warn("?"._T("Dit overicht is ter referentie, de boeking is niet uitgevoerd!")."\n") if $fail;
	EB::Report::Journal->new->journal
	    ({select => $bsk_id,
	      d_boekjaar => $bky,
	      detail => 1});
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

    join(":", $dbh->lookup($dagboek, qw(Dagboeken dbk_id dbk_desc)), $bsk_nr);
}

1;
