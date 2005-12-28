#!/usr/bin/perl -w
my $RCS_Id = '$Id: Balres.pm,v 1.13 2005/12/28 22:11:26 jv Exp $ ';

package main;

our $config;
our $app;
our $dbh;

package EB::Report::Balres;

# Author          : Johan Vromans
# Created On      : Sat Jun 11 13:44:43 2005
# Last Modified By: Johan Vromans
# Last Modified On: Sat Dec 24 21:52:38 2005
# Update Count    : 294
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use warnings;

################ The Process ################

use EB;
use EB::Report;

################ Subroutines ################

sub new {
    my ($class, $opts) = @_;
    $class = ref($class) || $class;
    $opts = {} unless $opts;
    bless { %$opts }, $class;
}

sub balans {
    my ($self, $opts) = @_;
    $opts->{balans} = 1;
    $self->perform($opts);
}

sub openingsbalans {
    my ($self, $opts) = @_;
    $opts->{balans} = -1;
    $self->perform($opts);
}

sub result {
    my ($self, $opts) = @_;
    $opts->{balans} = 0;
    $self->perform($opts);
}

sub perform {
    my ($self, $opts) = @_;

    my $balans = $opts->{balans};
    my $detail = $opts->{detail};
    $detail = $opts->{verdicht} ? 2 : -1 unless defined $detail;
    $opts->{detail} = $detail;

    my $dtot = 0;
    my $ctot = 0;
    my $rep = EB::Report::GenBase->backend($self, $opts);

    my ($begin, $end) = @{$rep->{periode}};
#    if ( $opts->{periode} ) {
#	($begin,$end) = @{$opts->{periode}};
#    }
#    elsif ( $opts->{boekjaar} ) {
#	$begin = $dbh->lookup($opts->{boekjaar}, qw(Boekjaren bky_code bky_begin));
#	$end = $dbh->lookup($opts->{boekjaar}, qw(Boekjaren bky_code bky_end));
#	unless ( $end ) {
#	    warn("?".__x("Onbekend boekjaar: {code}", code => $opts->{boekjaar})."\n");
#	    return;
#	}
#    }
#    else {
#	$begin = $dbh->adm("begin");
#	$end = $dbh->adm("end");
#    }

    my $now = $opts->{per} || $end;
    $now = $ENV{EB_SQL_NOW} if $ENV{EB_SQL_NOW} && $ENV{EB_SQL_NOW} lt $now;
    $now = iso8601date() if $now gt iso8601date();

    my $sth;
    my $rr;
    my $table = "Accounts";
    if ( $balans < 0 ) {
	my $date = $dbh->adm("begin");
	$rep->start(_T("Openingsbalans"),
		    __x("Datum: {date}", date => $now));
    }
    else {
	if ( $balans ) {
	    $table = EB::Report->GetTAccountsBal($now);
	}
	elsif ( !$balans ) {
	    $table = EB::Report->GetTAccountsRes($begin, $now);
	}
	$rep->start($balans ? _T("Balans") : _T("Verlies/Winst"),
		    $balans ? __x("Periode: t/m {to}", to => $now) :
		    __x("Periode: {from} t/m {to}", from => $begin, to => $now));
    }

    if ( $detail >= 0 ) {	# Verdicht
	my @vd;
	my @hvd;
	$sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
			      " FROM Verdichtingen".
			      " WHERE".($balans ? "" : " NOT")." vdi_balres".
			      " AND vdi_struct IS NULL".
			      " ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    $hvd[$rr->[0]] = [ @$rr, []];
	}
	$sth->finish;
	@vd = @hvd;
	$sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc, vdi_struct".
			      " FROM Verdichtingen".
			      " WHERE".($balans ? "" : " NOT")." vdi_balres".
			      " AND vdi_struct IS NOT NULL".
			      " ORDER BY vdi_id");
	while ( $rr = $sth->fetchrow_arrayref ) {
	    push(@{$hvd[$rr->[2]]->[2]}, [@$rr]);
	    @vd[$rr->[0]] = [@$rr];
	}
	$sth->finish;

	foreach my $hvd ( @hvd ) {
	    next unless defined $hvd;
	    my $did_hvd = 0;
	    my $dstot = 0;
	    my $cstot = 0;
	    foreach my $vd ( @{$hvd->[2]} ) {
		my $did_vd = 0;
		$sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balance".
				      " FROM ${table}".
				      " WHERE".($balans ? "" : " NOT")." acc_balres".
				      "  AND acc_struct = ?".
				      "  AND acc_balance <> 0".
				      " ORDER BY acc_id", $vd->[0]);

		my $dsstot = 0;
		my $csstot = 0;
		while ( $rr = $sth->fetchrow_arrayref ) {
		    $rep->addline('H1', $hvd->[0], $hvd->[1])
		      unless $detail < 1 || $did_hvd++;
		    $rep->addline('H2', $vd->[0], " ".$vd->[1])
		      unless $detail < 2 || $did_vd++;
		    my ($acc_id, $acc_desc, $acc_balance) = @$rr;
		    if ( $acc_balance >= 0 ) {
			$dsstot += $acc_balance;
			$rep->addline('D2', $acc_id, $acc_desc, $acc_balance, undef)
			  if $detail >= 2;
		    }
		    else {
			$csstot -= $acc_balance;
			$rep->addline('D2', $acc_id, $acc_desc, undef, -$acc_balance)
			  if $detail >= 2;
		    }
		}
		$sth->finish;
		if ( $detail >= 1 && ($csstot || $dsstot) ) {
		    $rep->addline('T2', $vd->[0],
				  ($detail > 1 ? __x("Totaal {vrd}", vrd => $vd->[1]) : $vd->[1]),
				  $dsstot >= $csstot ? ($dsstot-$csstot, undef) : (undef, $csstot-$dsstot));
		}
		$cstot += $csstot-$dsstot if $csstot>$dsstot;
		$dstot += $dsstot-$csstot if $dsstot>$csstot;
	    }
	    if ( $detail >= 0  && ($cstot || $dstot) ) {
		$rep->addline('T1', $hvd->[0],
			      ($detail > 0 ? __x("Totaal {vrd}", vrd => $hvd->[1]) : $hvd->[1]),
			      $dstot >= $cstot ? ($dstot-$cstot, undef) : (undef, $cstot-$dstot));

	    }
	    $ctot += $cstot-$dstot if $cstot>$dstot;
	    $dtot += $dstot-$cstot if $dstot>$cstot;
	}

    }
    else {			# Op Grootboek
	$sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_debcrd, acc_balance, acc_ibalance".
			      " FROM ${table}".
			      " WHERE".($balans ? "" : " NOT")." acc_balres".
			      "  AND acc_balance <> 0".
			      " ORDER BY acc_id");

	while ( $rr = $sth->fetchrow_arrayref ) {
	    my ($acc_id, $acc_desc, $acc_debcrd, $acc_balance, $acc_ibalance) = @$rr;
	    $acc_balance -= $acc_ibalance unless $opts->{balans};
	    if ( $acc_balance >= 0 ) {
		$dtot += $acc_balance;
		$rep->addline('D', $acc_id, $acc_desc, $acc_balance, undef);
	    }
	    else {
		$ctot -= $acc_balance;
		$rep->addline('D', $acc_id, $acc_desc, undef, -$acc_balance);
	    }
	}
	$sth->finish;
    }

    my ($w, $v) = (_T("Winst"), _T("Verlies"));
    ($w, $v) = ($v, $w) unless $balans;
    if ( $dtot != $ctot ) {
	if ( $dtot >= $ctot ) {
	    $rep->addline('V', $w, undef, $dtot - $ctot || "00");
	    $ctot = $dtot;
	}
	else {
	    $rep->addline('V', $v, $ctot - $dtot || "00", undef);
	    $dtot = $ctot;
	}
    }
    $rep->addline('T', __x("TOTAAL {rep}", rep => $balans ? _T("Balans") : _T("Resultaten")),
		  $dtot, $ctot);
    $rep->finish;

    # Rollback temp table.
    $dbh->rollback;
}

package EB::Report::Balres::Text;

use strict;
use warnings;

use EB;
use EB::Finance;
use base qw(EB::Report::GenBase);

sub new {
    my ($class, $opts) = @_;
    my $self = $class->SUPER::new($opts);
    $self;
}

# Format variables for headings.
my ($title, $period, $tag3, $adm, $now, $ident);

sub start {
    my ($self, $t1, $t2) = @_;
    $title = $t1;
    $period = $t2;
    $tag3 = $self->{detail} >= 0 ? _T("Verdichting/Grootboekrekening") : _T("Grootboekrekening");
    if ( $self->{boekjaar} ) {
	$adm = $dbh->lookup($self->{boekjaar},
			    qw(Boekjaren bky_code bky_name));
    }
    else {
	$adm = $dbh->adm("name");
    }
    $now = $ENV{EB_SQL_NOW} || iso8601date();
    $ident = $EB::ident;
    $ident = (split(' ', $ident))[0] if $ENV{EB_SQL_NOW};
    $self->{fh}->format_top_name('rt00');
}

# Format variables for report lines.
my ($acc, $desc, $deb, $crd);

sub addline {
    my ($self, $type) = (shift, shift);
    $acc = $type eq 'V' || $type eq 'T' ? "" : shift;
    ($desc, $deb, $crd) = @_;

    if ( $deb && $deb <= 0 && !$crd ) {
	($deb, $crd) = ('', -$deb);
    }
    elsif ( $crd && $crd <= 0 && !$deb ) {
	($deb, $crd) = (-$crd, '');
    }
    for ( $deb, $crd ) {
	$_ = $_ ? numfmt($_) : '';
    }

    if ( $type =~ /^D(\d+)/ ) {
	$desc = (" " x $1) . $desc;
    }
    elsif ( $type =~ /^[HT](\d+)/ ) {
	$desc = (" " x ($1-1)) . $desc;
    }
    elsif ( $type eq 'V' ) {
	$desc = "<< $desc >>";
    }
    if ( $type eq 'T' ) {
	$self->{fh}->format_write(__PACKAGE__.'::rtl');
	$self->{fh}->format_write(__PACKAGE__.'::rt01');
	return;
    }

    $self->{fh}->format_write(__PACKAGE__.'::rt01');
    if ( $type =~ /^T(\d+)$/ && $1 <= $self->{detail} ) {
	($acc, $desc, $deb, $crd) = ('') x 6;
	$self->{fh}->format_write(__PACKAGE__.'::rt01');
    }
}

sub finish {
}

format rt00 =
@|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||
$title
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
$period
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< @>>>>>>>>>>>>>>>>>>>>>>>>>>
$adm, $ident . ", " . $now

@<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>  @>>>>>>>>
_T("RekNr"), $tag3, _T("Debet"), _T("Credit")
----------------------------------------------------------------------
.

format rtl =
----------------------------------------------------------------------
.

format rt01 =
@<<<<<  @<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<  @>>>>>>>>  @>>>>>>>>
$acc, $desc, $deb, $crd
.

1;
