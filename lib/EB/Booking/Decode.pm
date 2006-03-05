my $RCS_Id = '$Id: Decode.pm,v 1.14 2006/03/05 21:06:10 jv Exp $ ';

package main;

our $dbh;
our $spp;
our $config;

package EB::Booking::Decode;

# Author          : Johan Vromans
# Created On      : Tue Sep 20 15:16:31 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Mar  5 21:56:40 2006
# Update Count    : 147
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
    my $ex_bky     = $opts->{bky};
    my $ex_debcrd  = $opts->{debcrd};
    my $ex_tot     = $opts->{totaal} || $opts->{total};
    my $no_ivbskdesc = $opts->{noivbskdesc};

    my $dbver = sprintf("%03d%03d%03d", $dbh->adm("scm_majversion"),
			$dbh->adm("scm_minversion")||0, $dbh->adm("scm_revision"));

    $bsk = $dbh->bskid($bsk);

    my $rr = $dbh->do("SELECT bsk_id, bsk_nr, bsk_desc, ".
		      "bsk_dbk_id, bsk_date, bsk_amount, bsk_saldo, bsk_bky ".
		      ($dbver lt "001000002" ? ", bsk_paid" : ", bsk_open").
		      " FROM Boekstukken".
		      " WHERE bsk_id = ?", $bsk);

    unless ( $rr ) {
	warn("?".__x("Onbekend boekstuk: {bsk}", bsk => $bsk)."\n");
	return;
    }

    my ($bsk_id, $bsk_nr, $bsk_desc, $bsk_dbk_id,
	$bsk_date, $bsk_amount, $bsk_saldo, $bsk_bky, $bsk_open) = @$rr;

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
	    $cmd .= ":$bsk_bky" if $ex_bky;
	    $cmd .= ":$bsk_nr" if $ex_bsknr;
	    $cmd .= " $bsk_date ";
	    if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
		$cmd .= $no_ivbskdesc ? "\"$rel_code\"" : "\"$bsk_desc\" \"$rel_code\"";
	    }
	    if ($dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS || $dbktype == DBKTYPE_MEMORIAAL) {
		$cmd .= "\"$bsk_desc\"";
	    }
	    else {
		$cmd .= " --totaal=" . numfmt($dbktype == DBKTYPE_INKOOP ? 0-$bsk_amount : $bsk_amount)
		  if $ex_tot && $acct;
	    }
	    $cmd .= " --saldo=" . numfmt($bsk_saldo) if $ex_tot && defined $bsk_saldo;
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
	    if ( $dbver lt "001000002" ) {
		$cmd .= $bsk_open ? ", *$bsk_open" : ", open"
	    }
	    elsif ( defined $bsk_open ) {
		$cmd .= $bsk_open ? ", @{[numfmt(abs($bsk_open))]} open" : ", voldaan"
	    }
	    $cmd .= "\n";
	}
    };

    my $sth = $dbh->sql_exec("SELECT bsr_id, bsr_nr, bsr_date, ".
			     "bsr_desc, bsr_amount, bsr_btw_id, bsr_btw_class, ".
			     "bsr_type, bsr_acc_id, bsr_rel_code, bsr_paid ".
			     " FROM Boekstukregels".
			     " WHERE bsr_bsk_id = ?".
			     " ORDER BY bsr_nr", $bsk);

    unless ( $sth->rows ) {
	# Special case for boekstuk zonder boekstukregels.
	$setup->(undef);
	return $cmd;
    }

    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($bsr_id, $bsr_nr, $bsr_date, $bsr_desc, $bsr_amount, $bsr_btw_id,
	    $bsr_btw_class, $bsr_type, $bsr_acc_id, $bsr_rel_code, $bsr_paid) = @$rr;
	if ( $bsr_nr == 1) {
	    $setup->($bsr_rel_code);
	}

	my ($rd, $rt, $acc_balres, $acc_kstomz) = $bsr_acc_id ?
	  @{$dbh->do("SELECT acc_desc,acc_debcrd,acc_balres,acc_kstomz".
		       " FROM Accounts".
		       " WHERE acc_id = ?",
		       $bsr_acc_id)}
	    : ("[Open posten vorige periode]", 1);

	my $dc = $bsr_amount >= 0 ? "debet" : "credit";
	$dc = uc($dc) unless (($bsr_amount < 0) xor $rt);
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

	croak("INTERNAL ERROR: BTW/N id = $bsr_btw_id")
	  if !($bsr_btw_class & BTWKLASSE_BTW_BIT) && $bsr_btw_id;

	my $a = EB::Finance::norm_btw($bsr_amount, $bsr_btw_id);
	$tot += $a->[0];

	next unless $trail;

	$bsr_acc_id ||= "";
	my $btw = "";

	# Refactor later.
	if ( $bsr_btw_class & BTWKLASSE_BTW_BIT ) {
	    my $ko = $bsr_btw_class & BTWKLASSE_KO_BIT ? 1 : 0;
	    if ( $ex_btw ) {
		$btw = $bsr_btw_id . qw(O K)[$ko];
	    }
	    else {
		$btw .= $bsr_btw_id
		  if btw_code($bsr_acc_id) != $bsr_btw_id
		    || ($bsr_type == 0 && $dbktype == DBKTYPE_MEMORIAAL);
		$btw .= qw(O K)[$ko]
		  if (!defined($acc_kstomz) || ($acc_kstomz xor $ko));
	    }
	}
	elsif ( $dbh->does_btw ) {
	    if ( $ex_btw ) {
		$btw = 'N';
	    }
	    else {
		$btw = 'N'
		  if defined($acc_kstomz);
	    }
	}

	$btw = '@' . $btw unless $btw eq "";

	if ( $dbktype == DBKTYPE_INKOOP || $dbktype == DBKTYPE_VERKOOP ) {
	    $bsr_amount = -$bsr_amount if $dbktype == DBKTYPE_VERKOOP;
	    $cmd .= $single ? " " : " \\\n\t";
	    $cmd .= "\"$bsr_desc\" " .
	      numfmt($bsr_amount) . $btw . " " .
		$bsr_acc_id;
	}
	elsif ( $dbktype == DBKTYPE_BANK || $dbktype == DBKTYPE_KAS
		|| $dbktype == DBKTYPE_MEMORIAAL ) {
	    $bsr_amount = -$bsr_amount;
	    my $dd = "";
	    $dd = " $bsr_date" unless $bsr_date eq $bsk_date;
	    if ( $bsr_type == 0 ) {
		$cmd .= $single ? " " : " \\\n\t";
		$cmd .= "std$dd \"$bsr_desc\" " .
		  numfmt($bsr_amount) . $btw . " " .
		    $bsr_acc_id;
	    }
	    elsif ( $bsr_type == 1 || $bsr_type == 2 ) {
		my $type = $bsr_type == 1 ? "deb" : "crd";
		$cmd .= $single ? " " : " \\\n\t";

		# Check for a full payment.
		my $sth = $dbh->sql_exec("SELECT bsk_amount, dbk_desc, bsk_nr, bsk_bky".
					 " FROM Boekstukken, Dagboeken".
					 " WHERE bsk_dbk_id = dbk_id".
					 " AND bsk_id = ?", $bsr_paid);
		my ($paid, $dbk, $nr, $bky) = @{$sth->fetchrow_arrayref};
		$sth->finish;
		if ( $paid == $bsr_amount) {
		    # Matches -> Full payment
		    $cmd .= "$type$dd \"$bsr_rel_code\" " .
		      numfmt($bsr_amount);
		}
		else {
		    # Partial payment. Use boekstuknummer.
		    $dbk = lc($dbk);
		    $dbk =~ s/[^[:alnum:]]/_/g;
		    $cmd .= "$type$dd $dbk";
		    $cmd .= ":$bky" if ($opts->{boekjaar}||$opts->{d_boekjaar}) ne $bky;
		    $cmd .= ":$nr " . numfmt($bsr_amount);
		}
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
    Carp::confess("acct is null") unless $acct;
    my $rr = $dbh->do("SELECT acc_btw".
		      " FROM Accounts".
		      " WHERE acc_id = ?", $acct);
    die("?".__x("Onbekend rekeningnummer: {acct}", acct => $acct)."\n")
      unless $rr;
    $btw_code{$acct} = $rr->[0];
}

1;
