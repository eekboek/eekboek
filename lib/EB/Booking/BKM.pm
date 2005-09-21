#!/usr/bin/perl -w
my $RCS_Id = '$Id: BKM.pm,v 1.18 2005/09/21 13:09:01 jv Exp $ ';

package main;

our $dbh;
our $app;
our $config;

package EB::Booking::BKM;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 21 13:15:21 2005
# Update Count    : 178
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

    my $dagboek = $opts->{dagboek};
    my $dagboek_type = $opts->{dagboek_type};
    my $totaal = $opts->{totaal};
    if ( defined($totaal) ) {
	$totaal = amount($totaal);
	return "?".__x("Ongeldig totaal: {total}", total => $totaal) unless defined $totaal;
	#$totaal = -$totaal if $dagboek_type == DBKTYPE_INKOOP;
    }

    my $date;
    if ( $args->[0] =~ /^\d+-\d+-\d+$/ ) {
	$date = shift(@$args);
    }
    elsif ( $args->[0] =~ /^(\d+)-(\d+)-(\d{4})$/ ) {
	$date = "$3-$2-$1";
	shift(@$args);
    }
    elsif ( $args->[0] =~ /^(\d+)-(\d+)$/ ) {
	$date = substr($dbh->adm("begin"), 0, 4) . "-$2-$1";
	shift(@$args);
    }
    else {
	my @tm = localtime(time);
	$date = sprintf("%04d-%02d-%02d",
			1900 + $tm[5], 1 + $tm[4], $tm[3]);
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
	    my $dd = parse_date($args->[0]);
	    shift(@$args) if $dd;
	    my ($desc, $amt, $acct) = splice(@$args, 0, 3);
	    warn(" "._T("boekstuk").": std $desc $amt $acct\n")
	      if $did++ || @$args || $opts->{verbose};

	    my $dc = "acc_debcrd";
	    if ( $acct =~ /^(\d+)([cd])/i ) {
		$acct = $1;
		$dc = lc($2) eq 'd' ? 1 : 0;
	    }
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

	    ($amt, $btw_id) = amount($amt, $btw_id);

	    my $group = $dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
	    my $btw_acc = $debcrd ?
	      $dbh->std_acc($group == BTWTYPE_HOOG ? "btw_ih" : "btw_il") :
		$dbh->std_acc($group == BTWTYPE_HOOG ? "btw_vh" : "btw_vl");

	    my $btw = 0;
	    my $bsr_amount = $amt;
	    my $orig_amount = $amt;
	    my ($btw_ink, $btw_verk);
	    if ( $btw_id ) {
		( $bsr_amount, $btw, $btw_ink, $btw_verk ) =
		  @{EB::Finance::norm_btw($bsr_amount, $btw_id)};
		$amt = $bsr_amount - $btw;
	    }
	    $orig_amount = -$orig_amount unless $debcrd;

	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				 bsr_btw_id bsr_btw_acc bsr_type bsr_acc_id bsr_rel_code)],
			     $nr++, $dd||$date, $bsk_id, $desc, $orig_amount,
			     $btw_id, $btw_acc, 0, $acct, undef);

	    $amt = -$amt, $btw = -$btw if $debcrd;
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
	    shift(@$args) if $dd;

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
			     what => lc($type eq "deb" ? _T("Debiteur") : _T("Crediteur")).
			     who => $rel)."\n");
		$fail++;
		next;
	    }

	    my $sql = "SELECT bsk_id, dbk_id, bsk_desc, bsk_amount ".
	      " FROM Boekstukken, Boekstukregels, Dagboeken" .
		" WHERE bsk_paid IS NULL".
		  ($amt ? "  AND ABS(bsk_amount) = ABS(?)" : "").
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
		warn("SQL: $sql\n");
		warn("args: @sql_args\n");
		$fail++;
		next;
	    }
	    my ($bskid, $dbk_id, $bsk_desc, $bsk_amount) = @$rr;

	    my $acct = $dbh->std_acc($debcrd ? "deb" : "crd");
	    $amt = $bsk_amount;

	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				 bsr_btw_id bsr_type bsr_acc_id bsr_rel_code)],
			     $nr++, $dd||$date, $bsk_id, "*".$bsk_desc,
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

    EB::Journal::Text->new->journal({select => $bsk_id, detail => 1}) if $opts->{journal};

    if ( $fail ) {
	$dbh->rollback;
	return undef;
    }
    $dbh->commit;

    $bsk_id;
}

1;
