my $RCS_Id = '$Id: Decode.pm,v 1.3 2005/10/01 13:24:29 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::Decode;

# Author          : Johan Vromans
# Created On      : Tue Sep 20 15:16:31 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Oct  1 12:06:07 2005
# Update Count    : 47
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

use EB;
use EB::Finance;

sub new {
    return bless {};
}

my @bsr_types =
  ([],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", ("") x 8, "Open post vorige periode" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [ "Standaard", "Betaling van debiteur", "Betaling aan crediteur" ],
   [],
  );

sub decode {
    my ($self, $bsk, $opts) = @_;

    my $trail	   = $opts->{trail};
    my $single	   = $opts->{single};
    my $ex_btw	   = $opts->{btw};
    my $ex_bsknr   = $opts->{bsknr};
    my $ex_debcrd  = $opts->{debcrd};

    $bsk = $dbh->bskid($bsk);

    my $rr = $dbh->do("SELECT bsk_id, bsk_nr, bsk_desc, ".
		      "bsk_dbk_id, bsk_date, bsk_amount, bsk_paid".
		      " FROM Boekstukken".
		      " WHERE bsk_id = ?", $bsk);

    unless ( $rr ) {
	warn("?".__x("Onbekend boekstuk: {bsk}", bsk => $bsk)."\n");
	return;
    }

    my ($bsk_id, $bsk_nr, $bsk_desc, $bsk_dbk_id,
	$bsk_date, $bsk_amount, $bsk_paid) = @$rr;
    $bsk_nr =~ s/\s+$//;

    my $tot = 0;
    my ($dbktype, $acct, $dbk_desc) = @{$dbh->do("SELECT dbk_type, dbk_acc_id, dbk_desc".
						 " FROM Dagboeken".
						 " WHERE dbk_id = ?", $bsk_dbk_id)};
    my $cmd = "";

    my $setup = sub {
	my ($rel_code) = @_;
	if ( $trail ) {
	    $cmd = lc($dbk_desc);
	    $cmd =~ s/[^[:alnum:]]/_/g;
	    $cmd .= ":$bsk_nr" if $ex_bsknr;
	    $cmd .= " $bsk_date ";
	    $cmd .= "\"$rel_code\""
	      if $dbktype == DBKTYPE_VERKOOP || $dbktype == DBKTYPE_INKOOP;
	    $cmd .= "\"$bsk_desc\""
	      if $dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS || $dbktype == DBKTYPE_MEMORIAAL;
	}
	else {
	    $cmd = "Boekstuk $bsk_id, nr $bsk_nr, dagboek " .
	      $dbh->lookup($bsk_dbk_id, qw(Dagboeken dbk_id dbk_desc =)).
		"($bsk_dbk_id)".
		  ", datum $bsk_date".
		    ", ";
	    if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
		my ($rd, $rt) = @{$dbh->do("SELECT rel_desc,rel_debcrd".
					   " FROM Relaties".
					   " WHERE rel_code = ?",
					   $rel_code)};
		$cmd .= $rt ? "deb " : "crd ";
		$cmd .= "$rel_code ($rd), ";
	    }
	    $cmd .= "\"$bsk_desc\"";
	    $cmd .= $bsk_paid ? ", *$bsk_paid" : ", open"
	      if $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP;
	    $cmd .= "\n";
	}
    };

    $bsk_nr =~ s/\s+$//;
    my $sth = $dbh->sql_exec("SELECT bsr_id, bsr_nr, bsr_date, ".
			     "bsr_desc, bsr_amount, bsr_btw_id, ".
			     "bsr_type, bsr_acc_id, bsr_rel_code ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?".
			     " ORDER BY bsr_nr", $bsk);

    unless ( $sth->rows ) {
	# Special case for boekstuk zonder boekstukregels.
	$setup->(undef);
	return $cmd;
    }

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount,
	    $bsr_btw_id, $bsr_type, $bsr_acc_id, $bsr_rel_code) = @$rr;
	$bsr_rel_code =~ s/\s+$// if $bsr_rel_code;
	if ( $bsr_nr == 1) {
	    $setup->($bsr_rel_code);
	}

	my ($rd, $rt) = $bsr_acc_id ?
	  @{$dbh->do("SELECT acc_desc,acc_debcrd".
		       " FROM Accounts".
		       " WHERE acc_id = ?",
		       $bsr_acc_id)}
	    : ("[Open posten vorige periode]", 1);

	my $dc = $bsr_amount >= 0 ? "debet" : "credit";
	$dc = uc($dc) unless ($bsr_amount < 0) ^ $rt;
	$cmd .= join("",
		     " Boekstukregel $bsr_id, nr $bsr_nr, datum $bsr_date, ",
		     "\"$bsr_desc\"",
		     ", type $bsr_type (", $bsr_types[$dbktype][$bsr_type], ")\n",
		     "  ",
		     "bedrag ", numfmt(abs($bsr_amount)), " ", $dc,
		     defined($bsr_btw_id) ?
		     (", BTW code $bsr_btw_id (",
		      $dbh->lookup($bsr_btw_id, qw(BTWTabel btw_id btw_desc)),
		      ")") : (),
		     defined($bsr_acc_id) ? (", rek $bsr_acc_id (", $rt ? "D/" : "C/", $rd, ")",) : (),
		     "\n") unless $trail;

	#$bsr_amount = -$bsr_amount unless $rt;
	my $a = EB::Finance::norm_btw($bsr_amount, $bsr_btw_id);
	$tot += $a->[0];

	next unless $trail;

	my $btw = ($ex_btw || btw_code($bsr_acc_id) != $bsr_btw_id) ? '@'.$bsr_btw_id : "";
	$dc = uc(substr($dc,0,1));

	if ( $bsr_amount < 0 ) {
	    # This has already been incorporated in the DC status.
	    $bsr_amount = -$bsr_amount;
	}

	unless ( $ex_debcrd || $rt ^ ($dc eq "D") ) {
	    $dc = "";
	}

	if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
	    $cmd .= $single ? " " : " \\\n\t";
	    $cmd .= "\"$bsr_desc\" " .
	      numfmt($bsr_amount) . $btw . " " .
		$bsr_acc_id . $dc;
	}
	elsif ( $dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS
		|| $dbktype == DBKTYPE_MEMORIAAL ) {
	    if ( $bsr_type == 0 ) {
		$cmd .= $single ? " " : " \\\n\t";
		$cmd .= "std \"$bsr_desc\" " .
		  numfmt($bsr_amount) . $btw . " " .
		    $bsr_acc_id . $dc;
	    }
	    elsif ( $bsr_type == 1 ) {
		$cmd .= $single ? " " : " \\\n\t";
		$cmd .= "deb \"$bsr_rel_code\" " .
		  numfmt($bsr_amount);
	    }
	    elsif ( $bsr_type == 2 ) {
		$cmd .= $single ? " " : " \\\n\t";
		$cmd .= "crd \"$bsr_rel_code\" " .
		  numfmt($bsr_amount);
	    }
	}

    }
    return ($cmd, $tot, $bsk_amount, $acct)
      if wantarray;
    $cmd;
}

################ Subroutines ################

my %btw_code;
sub btw_code {
    my($acct) = @_;
    return $btw_code{$acct} if defined $btw_code{$acct};
    _lku($acct);
    $btw_code{$acct};
}

sub _lku {
    my ($acct) = @_;
    my $rr = $dbh->do("SELECT acc_btw".
		      " FROM Accounts".
		      " WHERE acc_id = ?", $acct);
    die("?".__x("Onbekend rekeningnummer: {acct}", acct => $acct)."\n")
      unless $rr;
    $btw_code{$acct} = $rr->[0];
}

1;
