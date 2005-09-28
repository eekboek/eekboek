#!/usr/bin/perl -w
my $RCS_Id = '$Id: BKM.pm,v 1.22 2005/09/28 20:55:49 jv Exp $ ';

package main;

our $dbh;
our $app;
our $config;

package EB::Booking::BKM;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 28 22:30:11 2005
# Update Count    : 239
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Dagboek type 3: Bank
# Dagboek type 4: Kas
# Dagboek type 5: Memoriaal

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
    if ( $date = parse_date($args->[0], substr($begin, 0, 4)) ) {
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

    my $gdesc = shift(@$args);

    my $nr = 1;
    my $bsk_id;
    my $gacct = $dbh->lookup($dagboek, qw(Dagboeken dbk_id dbk_acc_id));

    print(__x("Huidig saldo: {bal}",
	      bal => numfmt($dbh->lookup($gacct, qw(Accounts acc_id acc_balance)))), "\n")
      if $gacct;

    if ( $bsk_id = $opts->{boekstuk} ) {
	$dbh->set_sequence("bsk_nr_${dagboek}_seq", $bsk_id);
    }
    else {
	$bsk_id = $dbh->get_sequence("bsk_nr_${dagboek}_seq");
    }
    $dbh->sql_insert("Boekstukken",
		     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_paid)],
		     $bsk_id, $gdesc, $dagboek, $date, undef);
    $bsk_id = $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr");
    my $tot = 0;
    my $did = 0;
    my $fail = 0;

    while ( @$args ) {
	my $type = shift(@$args);

	if ( $type eq "std" ) {
	    my $dd = parse_date($args->[0], substr($begin, 0, 4));
	    if ( $dd ) {
		shift(@$args);
		if ( $dd lt $begin ) {
		    warn("?"._T("De boekingsdatum valt vóór aanvang van het boekjaar")."\n");
		    return;
		}

		if ( $dbh->adm("btwbegin") && $dd lt $dbh->adm("btwbegin") ) {
		    warn("?"._T("De boekingsdatum valt in de periode waarover al BTW aangifte is gedaan")."\n");
		    return;
		}
	    }
	    else {
		$dd = $date;
	    }

	    my ($desc, $amt, $acct) = splice(@$args, 0, 3);
	    warn(" "._T("boekstuk").": std $desc $amt $acct\n")
	      if $did++ || @$args || $opts->{verbose};

	    my $dc = "acc_debcrd";
	    my $explicit_dc;
	    if ( $acct =~ /^(\d+)([cd])/i ) {
#		$acct = $1;
#		$explicit_dc = $dc = lc($2) eq 'd' ? 1 : 0;
		warn("?"._T("De \"D\" of \"C\" toevoeging aan het rekeningnummer is hier niet toegestaan")."\n");
		$fail++;
		next;
	    }
	    $dc = 1;		# ####
	    my $rr = $dbh->do("SELECT acc_desc,acc_balres,$dc,acc_btw".
			      " FROM Accounts".
			      " WHERE acc_id = ?", $acct);
	    unless ( $rr ) {
		warn("?".__x("Onbekende grootboekrekening: {acct}",
			     acct => $acct)."\n");
		$fail++;
		next;
	    }
	    my ($adesc, $balres, $debcrd, $btw_id) = @$rr;

	    if ( $balres && $dagboek_type != DBKTYPE_MEMORIAAL ) {
		warn("!".__x("Grootboekrekening {acct} ({desc}) is een balansrekening",
			     acct => $acct, desc => $adesc)."\n") if 0;
		#$dbh->rollback;
		#return;
	    }

	    my $bid;
	    ($amt, $bid) = amount($amt, undef);
	    $btw_id = 0, undef($bid) if defined($bid) && !$bid; # override: @0

	    # If there's BTW associated, it must be explicitly confirmed.
	    if ( $btw_id && !defined($bid) ) {
		warn("?".__x("Boekingen met BTW zijn niet mogelijk in een {dbk}.".
			     " De BTW is op nul gesteld.",
			     dbk => $dagboek_type == DBKTYPE_BANK ? "bankboek" :
			     $dagboek_type == DBKTYPE_KAS ? "kasboek" :
			     "memoriaal")."\n");
		$btw_id = 0;
	    }
	    my $btw_acc;
	    if ( defined($bid) ) {
		if ( $bid =~ /^[hl]|[hl][iv]|[iv][hl]$/i ) {
		    $bid = lc($bid);
		    my $t = $bid =~ /h/ ? "h" : "l";
		    if ( $bid =~ /([iv])/ ) {
			$t = $1.$t;
		    }
		    else {
			$t = $amt < 0 ? "i$t" : "v$t";
		    }
		    $btw_acc = $dbh->std_acc("btw_$t");
		    $btw_id = $dbh->do("SELECT btw_id".
				       " FROM BTWTabel".
				       " WHERE btw_tariefgroep = ?".
				       " AND btw_incl",
				       $bid =~ /h/ ? BTWTYPE_HOOG : BTWTYPE_LAAG)->[0];
		}
		elsif ( $bid =~ /^\d+|\d+[iv]|[iv]\d+$/i ) {
		    my $t = $btw_id = $1 if $bid =~ /(\d+)/;
		    my $group = $dbh->lookup($t, qw(BTWTabel btw_id btw_tariefgroep));
		    unless ( $group ) {
			warn("?".__x("Ongeldige BTW codering: {cod}",
				     cod => '@'.$bid)."\n");
			$fail++;
			next;
		    }
		    if ( $bid =~ /([iv])/ ) {
			$t = $1;
		    }
		    else {
			$t = $amt < 0 ? "i" : "v";
		    }
		    $t .= $group == BTWTYPE_HOOG ? "h" : "l";
		    $btw_acc = $dbh->std_acc("btw_$t");
		}
		else {
		    warn("?".__x("Ongeldige BTW codering: {cod}",
				 cod => '@'.$bid)."\n");
		    $fail++;
		    next;
		}
	    }

#	    my $group = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
##	    my $btw_acc = $debcrd ?
#	    my $btw_acc = (defined($explicit_dc) ? !$explicit_dc : ($amt < 0))  ?
#	      $dbh->std_acc($group == BTWTYPE_HOOG ? "btw_ih" : "btw_il") :
#		$dbh->std_acc($group == BTWTYPE_HOOG ? "btw_vh" : "btw_vl");

	    my $btw = 0;
	    my $bsr_amount = $amt;
	    my $orig_amount = $amt;
	    my ($btw_ink, $btw_verk);
	    if ( $btw_id ) {
		( $bsr_amount, $btw, $btw_ink, $btw_verk ) =
		  @{EB::Finance::norm_btw($bsr_amount, $btw_id)};
		$amt = $bsr_amount - $btw;
	    }
	    $orig_amount = -$orig_amount;# unless $debcrd;

	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				 bsr_btw_id bsr_btw_acc bsr_type bsr_acc_id bsr_rel_code)],
			     $nr++, $dd, $bsk_id, $desc, $orig_amount,
			     $btw_id, $btw_acc, 0, $acct, undef);

#	    $amt = -$amt, $btw = -$btw if $debcrd;
	    warn("update $acct with ".numfmt(-$amt)."\n") if $trace_updates;
	    $dbh->upd_account($acct, -$amt);
	    $tot += $amt;

	    if ( $btw ) {
		my $btw_acct =
		  $dbh->lookup($acct, qw(Accounts acc_id acc_debcrd)) ? $btw_ink : $btw_verk;
		warn("update $btw_acct with ".numfmt(-$btw)."\n") if $trace_updates;
		$dbh->upd_account($btw_acct, -$btw);
		$tot += $btw;
	    }


	}
	elsif ( $type eq "deb" || $type eq "crd" ) {
	    my $debcrd = $type eq "deb" ? 1 : 0;
	    my $dd = parse_date($args->[0]);
	    if ( $dd ) {
		shift(@$args);
		if ( $dd lt $begin ) {
		    warn("?"._T("De boekingsdatum valt vóór aanvang van het boekjaar")."\n");
		    return;
		}
		if ( $dbh->adm("btwbegin") && $dd lt $dbh->adm("btwbegin") ) {
		    warn("?"._T("De boekingsdatum valt in de periode waarover al BTW aangifte is gedaan")."\n");
		    return;
		}
	    }
	    else {
		$dd = $date;
	    }

	    my ($rel, $amt) = splice(@$args, 0, 2);
	    warn(" "._T("boekstuk").": $type $rel $amt\n")
	      if $did++ || @$args || $opts->{verbose};

	    $amt = amount($amt);

	    my $rr = $dbh->do("SELECT rel_acc_id FROM Relaties" .
			      " WHERE rel_code = ?" .
			      "  AND " . ($debcrd ? "" : "NOT ") . "rel_debcrd",
			      $rel);
	    unless ( defined($rr) ) {
		warn("?".__x("Onbekende {what}: {who}",
			     what => lc($type eq "deb" ? _T("Debiteur") : _T("Crediteur")),
			     who => $rel)."\n");
		$fail++;
		next;
	    }

	    my $sql = "SELECT bsk_id, dbk_id, bsk_desc, bsk_amount ".
	      " FROM Boekstukken, Boekstukregels, Dagboeken" .
		" WHERE bsk_paid IS NULL".
#		  ($amt ? "  AND ABS(bsk_amount) = ABS(?)" : "").
		  ($amt ? "  AND bsk_amount = ?" : "").
		    "  AND dbk_type = ?".
		      "  AND bsk_dbk_id = dbk_id".
			"  AND bsr_bsk_id = bsk_id".
			  "  AND bsr_rel_code = ?".
			    " ORDER BY bsk_id";
	    my @sql_args = ( $amt ? $amt : (),
			   $debcrd ? DBKTYPE_VERKOOP : DBKTYPE_INKOOP,
			   $rel );
	    $rr = $dbh->do($sql, @sql_args);
	    unless ( defined($rr) ) {
		warn("?"._T("Geen bijbehorende open post gevonden")."\n");
		warn("DEBUG: SQL: $sql\n");
		warn("DEBUG: args: @sql_args\n");
		$fail++;
		next;
	    }
	    my ($bskid, $dbk_id, $bsk_desc, $bsk_amount) = @$rr;
#	    warn("%".__x("Bedrag = {amt}, boekstuk = {bsk}",
#			 amt => numfmt($amt), bsk => numfmt($bsk_amount))."\n");

	    my $acct = $dbh->std_acc($debcrd ? "deb" : "crd");
	    $amt = $bsk_amount;

	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				 bsr_btw_id bsr_type bsr_acc_id bsr_rel_code)],
			     $nr++, $dd, $bsk_id, "*".$bsk_desc,
#			     $debcrd ? -$amt : $amt,
			     -$amt,
			     0, $type eq "deb" ? 1 : 2, $acct, $rel);
	    my $id = $dbh->get_sequence("boekstukregels_bsr_id_seq", "noincr");
	    $dbh->sql_exec("UPDATE Boekstukken".
			   " SET bsk_paid = ?".
			   " WHERE bsk_id = ?",
			   $id, $bskid);

	    warn("update $acct with ".numfmt(-$amt)."\n") if $trace_updates;
	    $dbh->upd_account($acct, -$amt);
	    $tot += $amt;
	}
	else {
	    warn("?".__x("Onbekend transactietype: {type}", type => $type)."\n");
	    $fail++;
	    next;
	}
	#print("sub = $tot\n");
    }

    if ( $gacct ) {
	warn("update $gacct with ".numfmt($tot)."\n") if $trace_updates;
	$dbh->upd_account($gacct, $tot);
	my $new = $dbh->lookup($gacct, qw(Accounts acc_id acc_balance));
	print(__x("Nieuw saldo: {bal}", bal => numfmt($new)), "\n");
	if ( $opts->{saldo} ) {
	    my $exp = amount($opts->{saldo});
	    unless ( $exp == $new ) {
		warn("?".__x("Saldo {new} klopt niet met de vereiste waarde {act}",
			     new => numfmt($new), act => numfmt($exp))."\n");
		$fail++;
	    }
	}
	if ( defined($totaal) and $tot != $totaal ) {
	    $fail++;
	    return "?"._T("Opdracht niet uitgevoerd.")." ".
	      __x(" Boekstuk totaal is {act} in plaats van {exp}",
		  act => numfmt($tot), exp => numfmt($totaal)) . ".";
	}
    }
    elsif ( $tot ) {
	warn("?".__x("Boekstuk is niet in balans (verschil is {diff})",
		     diff => numfmt($tot)).")\n");
	$fail++;
    }
    $dbh->sql_exec("UPDATE Boekstukken SET bsk_amount = ? WHERE bsk_id = ?",
		   $tot, $bsk_id)->finish;

    $dbh->store_journal(EB::Finance::journalise($bsk_id));

    if ( $opts->{journal} ) {
	warn("?"._T("Dit overicht is ter referentie, de boeking is niet uitgevoerd!")."\n") if $fail;
	EB::Journal::Text->new->journal({select => $bsk_id, detail => 1});
    }

    if ( $fail ) {
	warn("?"._T("De boeking is niet uitgevoerd!")."\n");
	$dbh->rollback;
	return undef;
    }
    $dbh->commit;

    $bsk_id;
}

1;
