#!/usr/bin/perl -w
my $RCS_Id = '$Id: BTWAangifte.pm,v 1.19 2005/12/02 15:36:59 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Tue Jul 19 19:01:33 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Dec  2 16:36:41 2005
# Update Count    : 334
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $dbh;

package EB::Report::BTWAangifte;

use strict;

use EB;
use EB::Finance;

use POSIX qw(floor ceil);

my @periodetabel;

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $self = {};
    bless $self, $class;
    $self->{"adm_$_"} = $dbh->adm($_)
      for qw(begin name btwperiod);
    $self->{adm_btwperiod} ||= 4;

    unless ( $self->{adm_begin} ) {
	die("?"._T("De administratie is nog niet geopend")."\n");
    }

    unless ( @periodetabel ) {
	@periodetabel = ( [] ) x 13;
	my @m;
	for ( 1 .. 12 ) {
	    push(@m, [ sprintf("%02d-01", $_),
		       sprintf("%02d-%02d", $_, ($_ & 1 xor $_ & 8) ? 31 : 30) ]);
	}
	$m[1][1] = substr($self->{adm_begin}, 0, 4) % 4 ? "02-28" : "02-29";
	$periodetabel[12] = [ _T("per maand"), @m ];
	$periodetabel[1]  = [ _T("per jaar"), [$m[0][0], $m[11][1] ]];
	$periodetabel[4]  = [ _T("per kwartaal"),
			      [$m[0][0], $m[2][1]], [$m[3][0], $m[5][1] ],
			      [$m[6][0], $m[8][1]], [$m[9][0], $m[11][1]]];
    }

    $self;
}

sub periodetabel {
    \@periodetabel;
}

use EB::Report::GenBase;

sub perform {
    my ($self, $opts) = @_;
    $self->collect($opts);

    $self->{reporter} = EB::Report::GenBase->backend($self, $opts);
    $self->report($opts);
}

sub periode {
    my ($self, $p, $year, $v) = @_;
    if ( $p == 1 ) {
	return __x("{year}", year => $year);
    }
    elsif ( $p == 4 ) {
	return __x("{quarter} {year}",
		   quarter => (_T("1e kwartaal"), _T("2e kwartaal"),
			       _T("3e kwartaal"), _T("4e kwartaal"))[$v-1],
		   year => $year);
    }
    elsif ( $p == 12 ) {
	return __x("{month} {year}",
		   month => $EB::month_names[$v-1],
		   year => $year);
    }
    else {
	die("?".__x("Programmafout: Ongeldige BTW periode: {per}", per => $p)."\n");
    }
}

sub parse_periode {
    my ($self, $v) = @_;
    my $year = substr($self->{adm_begin}, 0, 4);

    my $pp = sub {
	my ($per, $n) = @_;
	unless ( $self->{adm_btwperiod} == $per ) {
	    warn($self->{close} ? "?" :"!".
		 __x("Aangifte {per} komt niet overeen met de BTW instelling".
		     " van de administratie ({admper})",
		     per => $periodetabel[$per][0],
		     admper => $periodetabel[$self->{adm_btwperiod}][0],
		    )."\n")
	}
	$self->{adm_btwperiod} = $per;
	my $tbl = $periodetabel[$self->{adm_btwperiod}];
	$self->{p_start} = $year . "-" . $tbl->[$n]->[0];
	$self->{p_end}   = $year . "-" . $tbl->[$n]->[1];
	$self->{periode} = $self->periode($per, $year, $n);
	if ( $per == $n ) {
	    $self->{p_next}  = ($year+1) . "-" . $tbl->[1]->[0];
	}
	else {
	    $self->{p_next}  = $year . "-" . $tbl->[$n+1]->[0];
	}
    };

    my $yrpat = _T("j(aar)?");
    if ( $v =~ /^$yrpat$|j(aar)?$/i ) {
	$pp->(1, 1);
	return;
    }
    if ( $v =~ /^[kq](\d)$/i && $1 >= 1 && $1 <= 4) {
	$pp->(4, $1);
	return;
    }
    if ( $v =~ /^(\d+)$/i  && $1 >= 1 && $1 <= 12) {
	$pp->(12, $1);
	return;
    }
    if ( $v =~ /^(\w+)$/i ) {
	my $i;
	for ( $i = 0; $i < 12; $i++ ) {
	    last if lc($EB::month_names[$i]) eq lc($v);
	    last if lc($EB::months[$i]) eq lc($v);
	}
	if ( $i < 12 ) {
	    $pp->(12, $i+1);
	    return;
	}
    }
    die("?".__x("Ongeldige waarde voor BTW periode: \"{per}\"",
		per => $v) . "\n");
}

sub collect {
    my ($self, $opts) = @_;

    $self->{periode} = delete($opts->{periode});

    $self->parse_periode($self->{periode}) if $self->{periode};

    unless ( $self->{periode} ) {
	my $year = substr($self->{adm_begin}, 0, 4);
	my $tbl = $self->periodetabel->[$self->{adm_btwperiod}];
	if ( $self->{adm_btwperiod} == 1 ) {
	    $self->{p_start} = $year . "-" . $tbl->[1]->[0];
	    $self->{p_end}   = $year . "-" . $tbl->[1]->[1];
	    $self->{periode} = $self->periode(1, $year);
	}
	else {
	    my @tm = localtime(time);
	    $tm[5] += 1900;
	    my $m;
	    if ( $year < 1900+$tm[5] ) {
		$m = $self->{adm_btwperiod};
	    }
	    else {
		$m = 1 + int($tm[4] / (12/$self->{adm_btwperiod}));
	    }
	    $self->{p_start} = $year . "-" . $tbl->[$m]->[0];
	    $self->{p_end}   = $year . "-" . $tbl->[$m]->[1];
	    $self->{periode} = $self->periode($self->{adm_btwperiod}, $year, $m);
	}
    }

    unless ( $self->{p_start} eq $dbh->adm("btwbegin") ) {
	my $msg = _T("BTW aangifte periode sluit niet aan bij de vorige aangifte");
	$opts->{close} ? die("?$msg\n") : warn("!$msg\n");
    }

    # Target: alle boekstukken van type 0 (inkoop/verkoop).
    my $sth = $::dbh->sql_exec
      ("SELECT bsr_amount,bsr_acc_id,bsr_btw_id,bsr_btw_acc,rel_debcrd,rel_btw_status".
       " FROM Boekstukregels, Relaties".
       " WHERE bsr_rel_code = rel_code".
       ($self->{periode} ? " AND bsr_date >= ? AND bsr_date <= ?" : "").
       " AND bsr_type = 0".
#       " UNION ".
#       "SELECT bsr_amount,bsr_acc_id,bsr_btw_id,bsr_btw_acc,NOT acc_debcrd,0".
#       " FROM Boekstukregels, Accounts, Boekstukken".
#       " WHERE bsr_bsk_id = bsk_id".
#       " AND bsr_rel_code IS NULL".
#       " AND bsr_acc_id = acc_id".
#       " AND bsr_type = 0 and bsk_dbk_id = 3 AND bsr_btw_id <> 0",
       "",
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
    my $intra_deb_btw = 0;

    # 4. Aan mij verrichte leveringen
    # 4a. Van buiten de EU

    my $extra_crd = 0;

    # 4b. Verwervingen van goederen uit de EU.

    my $intra_crd = 0;
    my $intra_crd_btw = 0;

    # Totaaltellingen.

    my $crd_btw = 0;		# BTW betaald (voorheffingen)
    my $xx = 0;			# ongeclassificeerd (fout, dus)

    my $rr;
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($amt, $acc, $btw_id, $btw_acc, $debcrd, $btw_status) = @$rr;
	my $btg_id = 0;
	my $btw = 0;
	$amt = -$amt;
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
		$intra_deb_btw += $btw;
	    }
	    else {
		$intra_crd -= $amt;
		$intra_crd_btw -= $btw;
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
    $data{intra_deb_btw} = rounddown($intra_deb_btw); # TODO

    # 4. Aan mij verrichte leveringen
    # 4a. Van buiten de EU
    $data{extra_crd} = rounddown($extra_crd);

    # 4b. Verwervingen van goederen uit de EU.
    $data{intra_crd} = rounddown($intra_crd);
    $v = roundup($intra_crd_btw);
    $data{intra_crd_btw} = $v;
    $tot += $v;

    # 5 Berekening totaal
    # 5a. Subtotaal
    $data{sub0} = $tot;

    # 5b. Voorbelasting
    my ($vb) = @{$::dbh->do("SELECT SUM(jnl_amount)".
			    " FROM Journal".
			    " WHERE ( jnl_acc_id = ? OR jnl_acc_id = ? )".
			    ($self->{periode} ? " AND jnl_bsr_date >= ? AND jnl_bsr_date <= ?" : ""),
			    $dbh->std_acc("btw_ih"), $dbh->std_acc("btw_il"),
			    $self->{periode} ? ( $self->{p_start}, $self->{p_end} ) : ())};
    my $btw_delta = $vb - $crd_btw - $intra_crd_btw;

    $vb = roundup($vb);
    $data{vb} = $vb;
    $tot -= $vb;

    # 5c Subtotaal
    $data{sub1} = $tot;
    $data{onbekend} = $xx if $xx;

    $data{btw_delta} = $btw_delta if $btw_delta;

    $self->{data} = \%data;
}

sub report {
    my ($self, $opts) = @_;

    my $data = $self->{data};
    my $rep = $self->{reporter};

    $rep->start(_T("BTW Aangifte"),
		__x("Periode: {per}",
		    per => $self->{periode}));

    # Binnenland
    $rep->outline('H1', "Binnenland");

    # 1. Door mij verrichte leveringen/diensten
    $rep->outline('H2', "1.", "Door mij verrichte leveringen/diensten");

    # 1a. Belast met hoog tarief
    $rep->outline('', "1a", "Belast met hoog tarief", $data->{deb_h}, $data->{deb_btw_h});

    # 1b. Belast met laag tarief
    $rep->outline('', "1b", "Belast met laag tarief", $data->{deb_l}, $data->{deb_btw_l});

    # 1c. Belast met ander, niet-nul tarief
    $rep->outline('', "1c", "Belast met ander tarief", $data->{deb_x}, $data->{deb_btw_x});

    # 1d. Belast met 0%/verlegd
    $rep->outline('', "1d", "Belast met 0% / verlegd", $data->{deb_0}, undef);

    # Buitenland
    $rep->outline('H1', "Buitenland");

    # 3. Door mij verrichte leveringen
    $rep->outline('H2', "3.", "Door mij verrichte leveringen");

    # 3a. Buiten de EU
    $rep->outline('', "3a", "Buiten de EU", $data->{extra_deb}, undef);

    # 3b. Binnen de EU
    $rep->outline('', "3a", "Binnen de EU", $data->{intra_deb}, undef);

    # 4. Aan mij verrichte leveringen
    $rep->outline('H2', "4.", "Aan mij verrichte leveringen");

    # 4a. Van buiten de EU
    $rep->outline('', "4a", "Van buiten de EU", $data->{extra_crd}, 0);

    # 4b. Verwervingen van goederen uit de EU.
    $rep->outline('', "4b", "Verwervingen van goederen uit de EU",
		  $data->{intra_crd}, $data->{intra_crd_btw});

    # 5 Berekening totaal
    $rep->outline('H1', "Berekening");
    $rep->outline('H2', "5.", "Berekening totaal");

    # 5a. Subtotaal
    $rep->outline('', "5a", "Subtotaal", undef, $data->{sub0});

    # 5b. Voorbelasting
    $rep->outline('', "5b", "Voorbelasting", undef, $data->{vb});

    # 5c Subtotaal
    $rep->outline('', "5c", "Subtotaal", undef, $data->{sub1});

    $rep->outline('X', "xx", "Onbekend", undef, numfmt($data->{onbekend})) if $data->{onbekend};

    if ( $data->{btw_delta} ) {
	$rep->finish(__x("Er is een verschil van {amount}".
			 " tussen de berekende en werkelijk ingehouden BTW.".
			 " Voor de aangifte is de werkelijk ingehouden BTW gebruikt.",
			 amount => numfmt($data->{btw_delta})));
    }
    else {
	$rep->finish;
    }

    if ( $opts->{close} ) {
	$dbh->adm("btwbegin", $self->{p_next});	# implied commit
    }
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

package EB::Report::BTWAangifte::Text;

use strict;
use EB;
use base qw(EB::Report::GenBase);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

sub outline {
    my ($self, $ctl, $tag0, $tag1, $sub, $amt) = @_;
    $ctl = '' if $ctl && $ctl eq 'X';
    if ( $ctl ) {
	if ( $ctl eq 'H1' ) {
	    $self->{fh}->print("\n", $tag0, "\n");
	}
	elsif ( $ctl eq 'H2' ) {
	    $self->{fh}->print("\n", $tag0, " ", $tag1, "\n\n");
	}
	else {
	    die("?".__x("Ongeldige mode '{ctl}' in {pkg}::outline",
			ctl => $ctl,
			pkg => __PACKAGE__ ) . "\n");
	}
	return;
    }

    $self->{fh}->printf("%-5s%-40s%10s%10s\n",
			$tag0, $tag1,
			defined($sub) ? $sub : "",
			defined($amt) ? $amt : "");
}

sub start {
    my ($self, $text, $per) = @_;
    my $adm;
    if ( $self->{boekjaar} ) {
	$adm = $dbh->lookup($self->{boekjaar},
			    qw(Boekjaren bky_code bky_name));
    }
    else {
	$adm = $dbh->adm("name");
    }
    $self->{fh}->print($text, "\n", $per, "\n",
		       $adm, "\n");
}

sub finish {
    my ($self, $notice) = @_;
    warn("!$notice\n") if $notice;
    $self->{fh}->close;
}

1;
