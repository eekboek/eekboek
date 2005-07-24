#!/usr/bin/perl -w
my $RCS_Id = '$Id: BTWAangifte.pm,v 1.1 2005/07/24 19:33:02 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Tue Jul 19 19:01:33 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sun Jul 24 21:31:17 2005
# Update Count    : 186
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::BTWAangifte;

use strict;

use EB::Globals;
use POSIX qw(floor ceil);

my @periodetabel =
  ( [],
    [ "", [ "01-01", "12-31" ] ],
    [ "helft",
      [ "01-01", "06-30" ], [ "07-01", "12-31" ] ],
    [ "trimester",
      [ "01-01", "04-30" ], [ "05-01", "08-31" ], [ "09-01", "12-31" ] ],
    [ "kwartaal",
      [ "01-01", "03-31" ], [ "04-01", "06-30" ],
      [ "07-01", "09-30" ], [ "10-01", "12-31" ] ],
  );

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    bless $self, $class;
    @{$self}{qw(adm_begin adm_name adm_btw_periode)} =
      @{$::dbh->do("SELECT adm_begin, adm_name, adm_btwperiod FROM Metadata")};
    $self->{adm_btw_periode} ||= 4;

    unless ( $self->{adm_begin} ) {
	die("?Administratie is nog niet geopend\n");
    }
    $self;
}

sub periodetabel {
    \@periodetabel;
}

sub perform {
    my ($self, $opts) = @_;

    die("?EB::BTWAangifte kan alleen worden gebruikt via een afgeleide class, b.v. EB::Aangifte::Text\n");

}

sub parse_periode {
    my ($self, $v) = @_;
    my $year = substr($self->{adm_begin}, 0, 4);

    my $pp = sub {
	my ($per, $n) = @_;
	warn("!Periode \"$v\" komt niet overeen met administratie BTW periode \"$self->{adm_btw_periode}\"\n")
	  unless $self->{adm_btw_periode} == $per;
	$self->{adm_btw_periode} = $per;
	my $tbl = $periodetabel[$self->{adm_btw_periode}];
	$self->{p_start} = $year . "-" . $tbl->[$n]->[0];
	$self->{p_end}   = $year . "-" . $tbl->[$n]->[1];
	$self->{periode} = $n . "e " . $tbl->[0] . " " . $year;
    };

    if ( $v =~ /^j(aar)?$/i ) {
	$pp->(1, 1);
	$self->{periode} = $year;
    }
    elsif ( $v =~ /^[sh](\d)$/i && $1 >= 1 && $1 <= 2) {
	$pp->(2, $1);
    }
    elsif ( $v =~ /^[t](\d)$/i  && $1 >= 1 && $1 <= 3) {
	$pp->(3, $1);
    }
    elsif ( $v =~ /^[kq](\d)$/i && $1 >= 1 && $1 <= 4) {
	$pp->(4, $1);
    }
    else {
	die("?Ongeldige waarde \"$v\" voor periode\n");
    }
}

sub _perform {
    my ($self, $opts) = @_;

    $self->{periode} = $opts->{periode};

    $self->parse_periode($self->{periode}) if $self->{periode};

    unless ( $self->{periode} ) {
	my $year = substr($self->{adm_begin}, 0, 4);
	my $tbl = $self->periodetabel->[$self->{adm_btw_periode}];
	if ( $self->{adm_btw_periode} == 1 ) {
	    $self->{p_start} = $year . "-" . $tbl->[1]->[0];
	    $self->{p_end}   = $year . "-" . $tbl->[1]->[1];
	    $self->{periode} = $tbl->[0] . " " . $year;
	}
	else {
	    my @tm = localtime(time);
	    $tm[5] += 1900;
	    my $m;
	    if ( $year < 1900+$tm[5] ) {
		$m = $self->{adm_btw_periode};
	    }
	    else {
		$m = 1 + int($tm[4] / (12/$self->{adm_btw_periode}));
	    }
	    $self->{p_start} = $year . "-" . $tbl->[$m]->[0];
	    $self->{p_end}   = $year . "-" . $tbl->[$m]->[1];
	    $self->{periode} = $m . "e " . $tbl->[0] . " " . $year;
	}
    }

    # Target: alle boekstukken van type 0 (inkoop/verkoop).
    my $sth = $::dbh->sql_exec
      ("SELECT bsr_amount,bsr_acc_id,bsr_btw_id,bsr_btw_acc,rel_debcrd,rel_btw_status".
       " FROM Boekstukregels, Relaties".
       " WHERE bsr_rel_code = rel_code".
       ($self->{periode} ? " AND bsr_date >= ? AND bsr_date <= ?" : "").
       " AND bsr_type = 0",
       $self->{periode} ? ( $self->{p_start}, $self->{p_end} ) : ());

    my $v;

    my $tot = 0;

    # 1. Door mij verrichte leveringen/diensten
    # 1a. Belast met hoog tarief

    my $deb_h = 0;
    my $deb_btw_h = 0;

    # 1b. Belast met laag tarief

    my $deb_l = 0;
    my $deb_btw_l = 0;

    # 1c. Belast met ander, niet-nul tarief

    my $deb_x = 0;
    my $deb_btw_x = 0;

    # 1d. Belast met 0%/verlegd

    my $deb_0 = 0;
    my $verlegd = 0;

    # 3. Door mij verrichte leveringen
    # 3a. Buiten de EU

    my $extra_deb = 0;

    # 3b. Binnen de EU

    my $intra_deb = 0;

    # 4. Aan mij verrichte leveringen
    # 4a. Van buiten de EU

    my $extra_crd = 0;

    # 4b. Verwervingen van goederen uit de EU.

    my $intra_crd = 0;

    # Totaaltellingen.

    my $crd_btw = 0;		# BTW betaald (voorheffingen)
    my $xx = 0;			# ongeclassificeerd (fout, dus)

    my $rr;
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($amt, $acc, $btw_id, $btw_acc, $debcrd, $btw_status) = @$rr;
	my $btg_id = 0;
	my $btw = 0;
	$amt = -$amt if $::dbh->lookup($acc, qw(Accounts acc_id acc_debcrd));
	if ( $btw_id && $btw_acc ) {
	    # Bepaal tariefgroep en splits bedrag uit.
	    $btg_id = $::dbh->lookup($btw_id, qw(BTWTabel btw_id btw_tariefgroep));
	    my $a = EB::Finance::norm_btw($amt, $btw_id);
	    $amt = $a->[0] - ($btw = $a->[1]); # ex BTW
	}

	if ( $btw_status == BTW_NORMAAL ) {
	    if ( $debcrd ) {
		if ( $btg_id == BTWTYPE_HOOG ) {
		    $deb_h += $amt;
		    $deb_btw_h += $btw;
		}
		elsif ( $btg_id == BTWTYPE_LAAG ) {
		    $deb_l += $amt;
		    $deb_btw_l += $btw;
		}
		elsif ( $btg_id == BTWTYPE_GEEN ) {
		    $deb_0 += $amt
		      if $btw_acc;	# ???
		}
		else {
		    $deb_x += $amt;
		    $deb_btw_x += $btw;
		}
	    }
	    else {
		$crd_btw -= $btw;
	    }
	}
	elsif ( $btw_status == BTW_VERLEGD ) {
	    if ( $debcrd ) {
		$verlegd += $amt;
	    }
	}
	elsif ( $btw_status == BTW_INTRA ) {
	    if ( $debcrd ) {
		$intra_deb += $amt;
	    }
	    else {
		$intra_crd -= $amt;
	    }
	}
	elsif ( $btw_status == BTW_EXTRA ) {
	    if ( $debcrd ) {
		$extra_deb += $amt;
	    }
	    else {
		$extra_crd -= $amt;
	    }
	}
	else {
	    # Foutvanger.
	    $xx += $amt;
	}
    }

    my %data;
    # 1. Door mij verrichte leveringen/diensten
    # 1a. Belast met hoog tarief
    $v = rounddown($deb_btw_h);
    $data{deb_btw_h} = $v;
    $data{deb_h} = rounddown($deb_h);
    $tot += $v;

    # 1b. Belast met laag tarief
    $v = rounddown($deb_btw_l);
    $data{deb_l} = rounddown($deb_l);
    $data{deb_btw_l} = $v;
    $tot += $v;

    # 1c. Belast met ander, niet-nul tarief
    $v = rounddown($deb_btw_x);
    $data{deb_x} = $v;
    $tot += $v;

    # 1d. Belast met 0%/verlegd
    $data{deb_0} = rounddown($deb_0 + $verlegd);

    # Buitenland
    # 3. Door mij verrichte leveringen
    # 3a. Buiten de EU
    $data{extra_deb} = rounddown($extra_deb);

    # 3b. Binnen de EU
    $data{intra_deb} = rounddown($intra_deb);

    # 4. Aan mij verrichte leveringen
    # 4a. Van buiten de EU
    $data{extra_crd} = rounddown($extra_crd);

    # 4b. Verwervingen van goederen uit de EU.
    $data{intra_crd} = rounddown($intra_crd);

    # 5 Berekening totaal
    # 5a. Subtotaal
    $data{sub0} = $tot;

    # 5b. Voorbelasting
    my ($vb) = @{$::dbh->do("SELECT SUM(jnl_amount)".
			  " FROM Journal".
			  " WHERE ( jnl_acc_id = 1530 OR jnl_acc_id = 1520 )".
			  ($self->{periode} ? " AND jnl_date >= ? AND jnl_date <= ?" : ""),
			  $self->{periode} ? ( $self->{p_start}, $self->{p_end} ) : ())};
    my $btw_delta = $vb - $crd_btw;


    $vb = roundup($vb);
    $data{vb} = $vb;
    $tot -= $vb;

    # 5c Subtotaal
    $data{sub1} = $tot;
    $data{onbekend} = $xx if $xx;

    $data{btw_delta} = $btw_delta if $btw_delta;

    $self->{data} = \%data;
}

################ Subroutines ################

sub rounddown {
    my ($vb) = @_;
    return 0 unless $vb;
    $vb /= AMTSCALE;
    if ( $vb >= 0 ) {
	$vb = floor($vb);
    }
    else {
	$vb = -ceil(abs($vb));
    }
    $vb;
}

sub roundup {
    my ($vb) = @_;
    return 0 unless $vb;
    $vb /= AMTSCALE;
    if ( $vb >= 0 ) {
	$vb = ceil($vb);
    }
    else {
	$vb = -floor(abs($vb));
    }
    $vb;
}

sub outline {
    my ($tag0, $tag1, $sub, $amt) = @_;
    printf("%-5s%-40s%10s%10s\n",
	   $tag0, $tag1,
	   defined($sub) ? $sub : "",
	   defined($amt) ? $amt : "");
}

1;
