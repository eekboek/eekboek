#!/usr/bin/perl -w
my $RCS_Id = '$Id: BKM.pm,v 1.4 2005/07/20 08:18:01 jv Exp $ ';

package EB::Booking::BKM;

# Author          : Johan Vromans
# Created On      : Thu Jul  7 14:50:41 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Jul 19 17:05:54 2005
# Update Count    : 143
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

# Dagboek type 3: Bank
# Dagboek type 4: Kas
# Dagboek type 5: Memoriaal

use EB::Globals;
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

    my $date;
    if ( $args->[0] =~ /^\d+-\d+-\d+$/ ) {
	$date = shift(@$args);
    }
    else {
	my @tm = localtime(time);
	$date = sprintf("%04d-%02d-%02d",
			1900 + $tm[5], 1 + $tm[4], $tm[3]);
    }

    my $gdesc = shift(@$args);

    my $nr = 1;
    my $bsk_id;
    my $gacct = $::dbh->lookup($dagboek, qw(Dagboeken dbk_id dbk_acc_id));

    print("Huidig saldo: ",
	  numfmt($::dbh->lookup($gacct, qw(Accounts acc_id acc_balance))), "\n")
      if $gacct;

    $::dbh->sql_insert("Boekstukken",
		     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_paid)],
		     $::dbh->get_sequence("bsk_nr_${dagboek}_seq"),
		     $gdesc, $dagboek, $date, undef);
    $bsk_id = $::dbh->get_value("last_value", "boekstukken_bsk_id_seq");
    my $tot = 0;
    my $did = 0;
    my $fail = 0;

    while ( @$args ) {
	my $type = shift(@$args);

	if ( $type eq "std" ) {
	    my ($desc, $amt, $acct) = splice(@$args, 0, 3);
	    warn(" add$dagboek std $desc $amt $acct\n")
	      if $did++ || @$args || $opts->{verbose};

	    my $rr = $::dbh->do("SELECT acc_desc,acc_balres,acc_debcrd,acc_btw".
			      " FROM Accounts".
			      " WHERE acc_id = ?", $acct);
	    unless ( $rr ) {
		warn("?Onbekend rekeningnummer: $acct\n");
		$fail++;
		next;
	    }
	    my ($adesc, $balres, $debcrd, $btw_id) = @$rr;

	    if ( $balres && $dagboek_type != DBKTYPE_MEMORIAAL ) {
		warn("!Rekening $acct ($adesc) is een balansrekening\n");
		#$::dbh->rollback;
		#return;
	    }

	    ($amt, $btw_id) = amount($amt, $btw_id);

	    my $btw_acc;
	    $btw_acc = $::dbh->lookup($btw_id, "BTWTabel", "btw_id",
				      $debcrd ? "btw_acc_inkoop" : "btw_acc_verkoop");

	    my $btw = 0;
	    my $bsr_amount = $amt;
	    my ($btw_ink, $btw_verk);
	    if ( $btw_id ) {
		( $bsr_amount, $btw, $btw_ink, $btw_verk ) =
		  @{EB::Finance::norm_btw($bsr_amount, $btw_id)};
		$amt = $bsr_amount - $btw;
	    }

	    $::dbh->sql_insert("Boekstukregels",
			       [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				   bsr_btw_id bsr_btw_acc bsr_type bsr_acc_id bsr_rel_code)],
			       $nr++, $date, $bsk_id, $desc, $bsr_amount,
			       $btw_id, $btw_acc, 0, $acct, undef);

	    $amt = -$amt, $btw = -$btw if $debcrd;
	    warn("update $acct with ".numfmt(-$amt)."\n") if $trace_updates;
	    $::dbh->upd_account($acct, -$amt);
	    $tot += $amt;

	    if ( $btw ) {
		my $btw_acct =
		  $::dbh->lookup($acct, qw(Accounts acc_id acc_debcrd)) ? $btw_ink : $btw_verk;
		warn("update $btw_acct with ".numfmt(-$btw)."\n") if $trace_updates;
		$::dbh->upd_account($btw_acct, -$btw);
		$tot += $btw;
	    }


	}
	elsif ( $type eq "deb" || $type eq "crd" ) {
	    my $debcrd = $type eq "deb" ? 1 : 0;

	    my ($rel, $amt) = splice(@$args, 0, 2);
	    warn(" add$dagboek $type $rel $amt\n")
	      if $did++ || @$args || $opts->{verbose};

	    $amt = amount($amt);

	    my $rr = $::dbh->do("SELECT rel_acc_id FROM Relaties" .
			      " WHERE rel_code = ?" .
			      "  AND " . ($debcrd ? "" : "NOT ") . "rel_debcrd",
			      $rel);
	    unless ( defined($rr) ) {
		warn("?Onbekende ".
		     ($type eq "deb" ? "debiteur" : "crediteur").
		     ": $rel\n");
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
			    "";
	    my @sql_args = ( $amt ? $amt : (),
			   $debcrd ? DBKTYPE_VERKOOP : DBKTYPE_INKOOP,
			   $rel );
	    $rr = $::dbh->do($sql, @sql_args);
	    unless ( defined($rr) ) {
		warn("?Geen bijbehorende open post gevonden\n");
		warn("SQL: $sql\n");
		warn("args: @sql_args\n");
		$fail++;
		next;
	    }
	    my ($bskid, $dbk_id, $bsk_desc, $bsk_amount) = @$rr;

	    my $acct = $::dbh->std_acc($debcrd ? "deb" : "crd");
	    $amt = $bsk_amount;

	    $::dbh->sql_insert("Boekstukregels",
			       [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_amount
				   bsr_btw_id bsr_type bsr_acc_id bsr_rel_code)],
			       $nr++, $date, $bsk_id, "*".$bsk_desc,
			       $debcrd ? -$amt : $amt,
			       0, $type eq "deb" ? 1 : 2, $acct, $rel);
	    my $id = $::dbh->get_sequence("boekstukregels_bsr_id_seq", "noincr");
	    $::dbh->sql_exec("UPDATE Boekstukken".
			     " SET bsk_paid = ?".
			     " WHERE bsk_id = ?",
			     $id, $bskid);

	    warn("update $acct with ".numfmt(-$amt)."\n") if $trace_updates;
	    $::dbh->upd_account($acct, -$amt);
	    $tot += $amt;
	}
	else {
	    warn("?Onbekend transactietype: $type\n");
	    $fail++;
	    next;
	}
	#print("sub = $tot\n");
    }

    if ( $gacct ) {
	warn("update $gacct with ".numfmt($tot)."\n") if $trace_updates;
	$::dbh->upd_account($gacct, $tot);
	print("Nieuw saldo: ",
	      numfmt($::dbh->lookup($gacct, qw(Accounts acc_id acc_balance))), "\n");
    }
    elsif ( $tot ) {
	warn("?Boekstuk is niet in balans (verschil is ".numfmt($tot).")\n");
	$fail++;
    }
    $::dbh->sql_exec("UPDATE Boekstukken SET bsk_amount = ? WHERE bsk_id = ?",
		     $tot, $bsk_id)->finish;

    $::dbh->store_journal(EB::Finance::journalise($bsk_id));

    if ( $fail ) {
	$::dbh->rollback;
	return undef;
    }
    $::dbh->commit;

    EB::Journal::Text->new->journal($bsk_id) if $opts->{journal};

    $bsk_id;
}

1;
