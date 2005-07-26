#!/usr/bin/perl -w

use strict;
use warnings;

use EB::Globals;
use EB::DB;
use EB::Finance;

use locale;

our $trace = 0;

our $dbh = EB::DB->new(trace => $trace);

my $sth;

if ( @ARGV ) {
    my $nr = shift;
    if ( $nr =~ /^([[:alpha:]].+):(\d+)$/ ) {
	my $dbk = $::dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE bsk_nr = ?".
			      " AND dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY bsk_dbk_id,bsk_nr", $2, $dbk);
    }
    elsif ( $nr =~ /^([[:alpha:]].+)$/ ) {
	my $dbk = $::dbh->lookup($1, qw(Dagboeken dbk_desc dbk_id ilike));
	unless ( $dbk ) {
	    die("?Onbekend dagboek: $1\n");
	}
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken, Dagboeken".
			      " WHERE dbk_id = ?".
			      " AND bsk_dbk_id = dbk_id".
			      " ORDER BY bsk_dbk_id,bsk_nr", $dbk);
    }
    else {
	$sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			      " FROM Boekstukken".
			      " WHERE bsk_id = ?".
			      " ORDER BY bsk_dbk_id,bsk_nr", $nr);
    }
}
else {
    $sth = $dbh->sql_exec("SELECT bsk_id, bsk_nr, bsk_desc, ".
			  "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
			  " FROM Boekstukken".
			  " ORDER BY bsk_dbk_id,bsk_nr");
}

my $rr;

my $ret = [];
my $did = 0;

my @bsr_types =
  ([],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [],
  );

while ( $rr = $sth->fetchrow_arrayref ) {
    my ($bsk_id, $bsk_nr, $bsk_desc, $bsk_dbk_id,
	$bsk_date, $bsk_amount, $bsk_paid) = @$rr;
    $bsk_nr =~ s/\s+$//;
    my $sth = $dbh->sql_exec("SELECT bsr_id, bsr_nr, bsr_date, ".
			     "bsr_desc, bsr_amount, bsr_btw_id, ".
			     "bsr_type, bsr_acc_id, bsr_rel_code ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?".
			     " ORDER BY bsr_nr", $bsk_id);
    my $tot = 0;
    my $rr;
    my ($dbktype, $acct) = @{$dbh->do("SELECT dbk_type, dbk_acc_id".
				      " FROM Dagboeken".
				      " WHERE dbk_id = ?", $bsk_dbk_id)};
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount,
	    $bsr_btw_id, $bsr_type, $bsr_acc_id, $bsr_rel_code) = @$rr;
	$bsr_rel_code =~ s/\s+$// if $bsr_rel_code;

	if ( $bsr_nr == 1) {
	    print("\n") if $did++;
	    print("Boekstuk $bsk_id, nr $bsk_nr, dagboek ",
		  $dbh->lookup($bsk_dbk_id, qw(Dagboeken dbk_id dbk_desc =)),
		  "($bsk_dbk_id)",
		  ", datum $bsk_date",
		  ", ");
	    if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
		my ($rd, $rt) = @{$::dbh->do("SELECT rel_desc,rel_debcrd".
					     " FROM Relaties".
					     " WHERE rel_code = ?",
					     $bsr_rel_code)};
		print($rt ? "deb " : "crd ", "$bsr_rel_code ($rd), ");
	    }
	    print("\"$bsk_desc\"", $bsk_paid ? ", *$bsk_paid" : ", open", "\n");
	}

	my ($rd, $rt) = $bsr_acc_id ?
	  @{$::dbh->do("SELECT acc_desc,acc_debcrd".
		       " FROM Accounts".
		       " WHERE acc_id = ?",
		       $bsr_acc_id)}
	    : ("[Open posten vorige periode]", 1);

	print(" Boekstukregel $bsr_id, nr $bsr_nr, datum $bsr_date, ",
	      "\"$bsr_desc\"",
	      ", type $bsr_type (", $bsr_types[$dbktype][$bsr_type], ")\n",
	      "  ",
	      "\"$bsr_desc\", ",
	      "bedrag ", numfmt($bsr_amount),
#	      " ", $bsr_amount >= 0 ? "debet" : "credit",
	      defined($bsr_btw_id) ?
	      (", BTW code $bsr_btw_id (",
	      $dbh->lookup($bsr_btw_id, qw(BTWTabel btw_id btw_desc)),
	      ")") : (),
	      defined($bsr_acc_id) ? (", rek $bsr_acc_id (", $rt ? "D/" : "C/", $rd, ")",) : (),
	      "\n");

	$bsr_amount = -$bsr_amount unless $rt;
#	# The 'excl.' codes are for display purposes only.
#	$bsr_btw_id = 1 if $bsr_btw_id == 2; # ####TODO
#	$bsr_btw_id = 3 if $bsr_btw_id == 4; # ####TODO
	my $a = EB::Finance::norm_btw($bsr_amount, $bsr_btw_id);
#	print("=> ", (map { defined($_) ? numfmt($_) : "<undef>", " " } @$a), "\n");
	$tot += $a->[0];
    }

    unless ( $acct ) {
	print("BOEKSTUK IS NIET IN BALANS -- VERSCHIL IS ", numfmt($tot), "\n")
	  if $tot;
	next;
    }
    my ($rd, $rt) = @{$::dbh->do("SELECT acc_desc,acc_debcrd".
				 " FROM Accounts".
				 " WHERE acc_id = ?",
				 $acct)};

    $tot = -$tot if $rt;
    $bsk_amount = -$bsk_amount if $rt;
    print("TOTAAL Bedrag ", numfmt($tot),
	  ", rek $acct (",
	  $rt ? "D/" : "C/",
	  $rd, ")\n");
    print("TOTAAL BEDRAG ", numfmt($tot), " KLOPT NIET MET BOEKSTUK $bsk_id TOTAAL ", numfmt($bsk_amount), "\n")
#      unless $bsk_amount == $tot;
      # This silences a lot of warnings, have to find out why.
      unless abs($bsk_amount) == abs($tot);
}
