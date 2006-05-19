#!/usr/bin/perl -w
my $RCS_Id = '$Id: IV.pm,v 1.43 2006/05/19 10:41:36 jv Exp $ ';

package main;

our $cfg;
our $dbh;
our $spp;
our $config;

package EB::Booking::IV;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri May 19 12:37:36 2006
# Update Count    : 276
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Dagboek type 1: Inkoop
# Dagboek type 2: Verkoop

use EB;
use EB::DB;
use EB::Format;
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
    my $does_btw = $dbh->does_btw;

    my $bky = $self->{bky} ||= $opts->{boekjaar} || $dbh->adm("bky");

    if ( defined($totaal) ) {
	my $t = amount($totaal);
	return "?".__x("Ongeldig totaal: {total}", total => $totaal)
	  unless defined $t;
	$totaal = $t;
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
	  if ($args->[0]||"") =~ /^[[:digit:]]+-/;
	$date = iso8601date();
    }

    return "?"._T("Deze opdracht is onvolledig. Gebruik de \"help\" opdracht voor meer aanwijzingen.")."\n"
      unless @$args >= 3;

    return unless $self->in_bky($date, $begin, $end);

    if ( $does_btw && $dbh->adm("btwbegin") && $date lt $dbh->adm("btwbegin") ) {
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

    my ($rel_acc_id, $rel_btw);
    ($debcode, $rel_acc_id, $rel_btw) = @$rr;

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

	if  ( $acct !~ /^\d+$/ ) {
	    if ( $acct =~ /^(\d*)([cd])/i ) {
		warn("?"._T("De \"D\" of \"C\" toevoeging aan het rekeningnummer is hier niet toegestaan")."\n");
		return;
	    }
	    warn("?".__x("Ongeldig grootboekrekeningnummer: {acct}", acct => $acct )."\n");
	    return;
	}
	my $rr = $dbh->do("SELECT acc_desc,acc_balres,acc_kstomz,acc_debcrd,acc_btw".
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
	if ( $btw_id && !$does_btw ) {
	    croak("INTERNAL ERROR: ".
		  __x("Grootboekrekening {acct} heeft BTW in een BTW-vrije administratie",
		      acct => $acct));
	}

	if ( $nr == 1 ) {
	    $bsk_nr = $self->bsk_nr($opts);
	    return unless defined($bsk_nr);
	    $gdesc ||= $desc;
	    $dbh->sql_insert("Boekstukken",
			     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_bky)],
			     $bsk_nr, $gdesc, $dagboek, $date, $bky);
	    $bsk_id = $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr");
	}

	# Amount can override BTW id with @X postfix.
	my ($namt, $btw_spec) = $does_btw ? $self->amount_with_btw($amt, $btw_id) : amount($amt);
	unless ( defined($namt) ) {
	    warn("?".__x("Ongeldig bedrag: {amt}", amt => $amt)."\n");
	    return;
	}

	$amt = $iv ? $namt : -$namt;

	if ( $does_btw ) {
	    ($btw_id, $kstomz) = $self->parse_btw_spec($btw_spec, $btw_id, $kstomz);
	    unless ( defined($btw_id) ) {
		warn("?".__x("Ongeldige BTW-specificatie: {spec}", spec => $btw_spec)."\n");
		return;
	    }
	}

	# Bepalen van de BTW.
	# Voor neutrale boekingen (@N, of op een neutrale rekening) wordt geen BTW
	# toegepast. Op _alle_ andere wel. De BTW kan echter nul zijn, of void.
	# Het eerste wordt bewerkstelligd door $btw_id op 0 te zetten, het tweede
	# door $btw_acc geen waarde te geven.
	my $btwclass = 0;
	my $btw_acc;
	if ( defined($kstomz) ) {
	    # BTW toepassen.
	    if ( $kstomz ? !$iv : $iv ) {
		#warn("?".__x("U kunt geen {ko} boeken in een {iv} dagboek",
		warn("!".__x("Pas op! U boekt {ko} in een {iv} dagboek",
			     ko => $kstomz ? _T("kosten") : _T("omzet"),
			     iv => $iv ? _T("inkoop") : _T("verkoop"),
			    )."\n");
		#return;
	    }
	    # Void BTW voor non-EU en verlegd.
	    if ( $btw_id && ($rel_btw == BTWTYPE_NORMAAL || $rel_btw == BTWTYPE_INTRA) ) {
		my $tg = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
		unless ( defined($tg) ) {
		    warn("?".__x("Onbekende BTW-code: {code}", code => $btw_id)."\n");
		    return;
		}
		my $t = "btw_" . ($iv ? "i" : "v");
		$t .= $tg == BTWTARIEF_HOOG ? 'h' : 'l';
		$btw_acc = $dbh->std_acc($t);
	    }
	}
	elsif ( $btw_id ) {
	    warn("?"._T("BTW toepassen is niet mogelijk op een neutrale rekening")."\n");
	    return;
	}
	# ASSERT: $btw_id != 0 implies defined($kstomz).

	$dbh->sql_insert("Boekstukregels",
			 [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
			     bsr_btw_id bsr_btw_acc bsr_btw_class bsr_type bsr_acc_id bsr_rel_code)],
			 $nr++, $date, $bsk_id, $desc, $amt,
			 $btw_id, $btw_acc,
			 BTWKLASSE($does_btw ? defined($kstomz) : 0, $rel_btw, defined($kstomz) ? $kstomz : $iv),
			 0, $acct, $debcode);
    }

    my $ret = $self->journalise($bsk_id);
#    $rr = [ @$ret ];
#    shift(@$rr);
#    $rr = [ sort { $a->[5] <=> $b->[5] } @$rr ];
#    foreach my $r ( @$rr ) {
#	my (undef, undef, undef, undef, $nr, $ac, $amt) = @$r;
#	next unless $nr;
#	warn("update $ac with ".numfmt($amt)."\n") if $trace_updates;
#	$dbh->upd_account($ac, $amt);
#    }
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
