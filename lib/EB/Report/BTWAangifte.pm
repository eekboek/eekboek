#!/usr/bin/perl -w
my $RCS_Id = '$Id: BTWAangifte.pm,v 1.6 2005/09/21 08:57:01 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Tue Jul 19 19:01:33 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 21 10:56:22 2005
# Update Count    : 277
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::BTWAangifte;

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
    @{$self}{qw(adm_begin adm_name adm_btw_periode)} =
      @{$::dbh->do("SELECT adm_begin, adm_name, adm_btwperiod FROM Metadata")};
    $self->{adm_btw_periode} ||= 4;

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

sub perform {
    my ($self, $opts) = @_;
    $self->collect($opts);

    #use EB::BTWAangifte::Html;
    #$self->{reporter} ||= EB::BTWAangifte::Html->new($opts);
    $self->{reporter} = $opts->{reporter} || EB::BTWAangifte::Text->new($opts);

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
	warn("!".
	     __x("Aangifte {per} komt niet overeen met de BTW instelling".
		 " van de administratie ({admper})",
		 per => $periodetabel[$per][0],
		 admper => $periodetabel[$self->{adm_btw_periode}][0],
		)."\n")
	  unless $self->{adm_btw_periode} == $per;
	$self->{adm_btw_periode} = $per;
	my $tbl = $periodetabel[$self->{adm_btw_periode}];
	$self->{p_start} = $year . "-" . $tbl->[$n]->[0];
	$self->{p_end}   = $year . "-" . $tbl->[$n]->[1];
	$self->{periode} = $self->periode($per, $year, $n);
    };

    my $yrpat = _T("j(aar)?");
    if ( $v =~ /^$yrpat$/i ) {
	$pp->(1, 1);
    }
    elsif ( $v =~ /^[kq](\d)$/i && $1 >= 1 && $1 <= 4) {
	$pp->(4, $1);
    }
    elsif ( $v =~ /^(\d)$/i  && $1 >= 1 && $1 <= 12) {
	$pp->(12, $1);
    }
    else {
	die("?".__x("Ongeldige waarde voor BTW periode: \"{per}\"",
		    per => $v) . "\n");
    }
}

sub collect {
    my ($self, $opts) = @_;

    $self->{periode} = $opts->{periode};

    $self->parse_periode($self->{periode}) if $self->{periode};

    unless ( $self->{periode} ) {
	my $year = substr($self->{adm_begin}, 0, 4);
	my $tbl = $self->periodetabel->[$self->{adm_btw_periode}];
	if ( $self->{adm_btw_periode} == 1 ) {
	    $self->{p_start} = $year . "-" . $tbl->[1]->[0];
	    $self->{p_end}   = $year . "-" . $tbl->[1]->[1];
	    $self->{periode} = $self->periode(1, $year);
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
	    $self->{periode} = $self->periode($self->{adm_btw_periode}, $year, $m);
	}
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

sub report {
    my ($self, $opts) = @_;

    my $data = $self->{data};
    my $rep = $self->{reporter};

    $rep->start("BTW Aangifte $self->{periode} -- $self->{adm_name}");

    # Binnenland
    $rep->addline('H1', "Binnenland");

    # 1. Door mij verrichte leveringen/diensten
    $rep->addline('H2', "1.", "Door mij verrichte leveringen/diensten");

    # 1a. Belast met hoog tarief
    $rep->addline('', "1a", "Belast met hoog tarief", $data->{deb_h}, $data->{deb_btw_h});

    # 1b. Belast met laag tarief
    $rep->addline('', "1b", "Belast met laag tarief", $data->{deb_l}, $data->{deb_btw_l});

    # 1c. Belast met ander, niet-nul tarief
    $rep->addline('', "1c", "Belast met ander tarief", $data->{deb_x}, $data->{deb_btw_x});

    # 1d. Belast met 0%/verlegd
    $rep->addline('', "1c", "Belast met 0% / verlegd", $data->{deb_0}, undef);

    # Buitenland
    $rep->addline('H1', "Buitenland");

    # 3. Door mij verrichte leveringen
    $rep->addline('H2', "3.", "Door mij verrichte leveringen");

    # 3a. Buiten de EU
    $rep->addline('', "3a", "Buiten de EU", $data->{extra_deb}, undef);

    # 3b. Binnen de EU
    $rep->addline('', "3a", "Binnen de EU", $data->{intra_deb}, undef);

    # 4. Aan mij verrichte leveringen
    $rep->addline('H2', "4.", "Aan mij verrichte leveringen");

    # 4a. Van buiten de EU
    $rep->addline('', "4a", "Van buiten de EU", $data->{extra_crd}, 0);

    # 4b. Verwervingen van goederen uit de EU.
    $rep->addline('', "4b", "Verwervingen van goederen uit de EU", $data->{intra_crd}, 0);

    # 5 Berekening totaal
    $rep->addline('H1', "Berekening");
    $rep->addline('H2', "5.", "Berekening totaal");

    # 5a. Subtotaal
    $rep->addline('', "5a", "Subtotaal", undef, $data->{sub0});

    # 5b. Voorbelasting
    $rep->addline('', "5b", "Voorbelasting", undef, $data->{vb});

    # 5c Subtotaal
    $rep->addline('', "5c", "Subtotaal", undef, $data->{sub1});

    $rep->addline('X', "xx", "Onbekend", undef, numfmt($data->{onbekend})) if $data->{onbekend};

    if ( $data->{btw_delta} ) {
	$rep->finish(__x("Er is een verschil van {amount}".
			 " tussen de berekende en werkelijk ingehouden BTW.".
			 " Voor de aangifte is de werkelijk ingehouden BTW gebruikt.",
			 amount => numfmt($data->{btw_delta})));
    }
    else {
	$rep->finish;
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

package EB::BTWAangifte::Text;

use strict;

sub new {
    my ($class) = @_;
    $class = ref($class) || $class;
    bless {} => $class;
}

sub addline {
    my ($self, $ctl, $tag0, $tag1, $sub, $amt) = @_;
    $ctl = '' if $ctl && $ctl eq 'X';
    if ( $ctl ) {
	if ( $ctl eq 'H1' ) {
	    print("\n", $tag0, "\n");
	}
	elsif ( $ctl eq 'H2' ) {
	    print("\n", $tag0, " ", $tag1, "\n\n");
	}
	else {
	    die("?".__x("Ongeldige mode '{ctl}' in {pkg}::addline",
			ctl => $ctl,
			pkg => __PACKAGE__ ) . "\n");
	}
	return;
    }

    printf("%-5s%-40s%10s%10s\n",
	   $tag0, $tag1,
	   defined($sub) ? $sub : "",
	   defined($amt) ? $amt : "");
}

sub start {
    my ($self, $text) = @_;
    print($text, "\n");
}

sub finish {
    my ($self, $notice) = @_;
    warn("!$notice\n") if $notice;
}

1;
