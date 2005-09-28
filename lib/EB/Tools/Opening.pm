# $Id: Opening.pm,v 1.8 2005/09/28 19:53:34 jv Exp $

# Author          : Johan Vromans
# Created On      : Tue Aug 30 09:49:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Wed Sep 28 19:06:30 2005
# Update Count    : 40
# Status          : Unknown, Use with caution!

package main;

our $dbh;
our $app;
our $config;

package EB::Tools::Opening;

use strict;
use EB;
use EB::Finance;
use EB::DB;

# List of API methods (for the shell).
sub commands {
    [qw(open set_naam set_btwperiode set_begindatum set_balanstotaal
	set_balans set_relatie)];
}

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    bless {}, $class;
}

# Shell methods.
# NOTE: A true result means ERROR!
sub set_naam {
    return shellhelp() unless @_ == 2;
    my ($self, $naam) = @_;
    $self->check_open(0);
    $self->{o}->{naam} = $naam;
    "";
}

sub set_btwperiode {
    return shellhelp() unless @_ == 2;
    my ($self, $per) = @_;
    my $pat = join("|", _T("jaar"), _T("maand"), _T("kwartaal"));
    return __x("Ongeldige BTW periode: {per}", per => $per)."\n"
      unless $per =~ /^$pat|jaar|maand}kwartaal$/i;
    $self->check_open(0);
    $self->{o}->{btwperiode} = 1 if lc($per) eq _T("jaar") || lc($per) eq "jaar";
    $self->{o}->{btwperiode} = 4 if lc($per) eq _T("kwartaal") || lc($per) eq "kwartaal";
    $self->{o}->{btwperiode} = 12 if lc($per) eq _T("maand") || lc($per) eq "maand";
    ""
}

sub set_begindatum {
    return shellhelp() unless @_ == 2;
    my ($self, $jaar) = @_;
    return __x("Ongeldige jaar-aanduiding: {year}", year => $jaar)."\n" unless $jaar =~ /^\d+$/
      && $jaar >= 1990 && $jaar < 2099;	# TODO
    $self->check_open(0);
    $self->{o}->{begindatum} = $jaar;
    "";
}

sub set_balanstotaal {
    return shellhelp() unless @_ == 2;
    my ($self, $amt) = @_;
    return __x("Ongeldig bedrag: {amount}", amount => $amt)."\n" unless defined($amt = amount($amt));
    $self->check_open(0);
    $self->{o}->{balanstotaal} = $amt;
    "";
}

sub set_balans {
    return shellhelp() unless @_ == 3;
    my ($self, $acct, $amt) = @_;
    my $rr = $dbh->do("SELECT acc_balres, acc_debcrd".
		      " FROM Accounts".
		      " WHERE acc_id = ?", $acct);
    return __x("Onbekende grootboekrekening: {acct}", acct => $acct)."\n"
      unless defined($rr);
    my $balres = $rr->[0];
    return __x("Grootboekrekening {acct} is geen balansrekening", acct => $acct)."\n"
      unless $balres;
    my $debcrd;
    if ( $amt =~ /^(.*)([DC])/ ) {
	$amt = $1;
	$debcrd = $2 eq "D";
    }
    else {
	$debcrd = $rr->[1];
    }
    return __x("Ongeldig bedrag: {amount}", amount => $amt)."\n" unless defined($amt = amount($amt));
    $self->check_open(0);
    push(@{$self->{o}->{balans}}, [$acct, $debcrd ? $amt : -$amt]);
    "";
}

sub set_relatie {
    return shellhelp() unless @_ == 6;
    my ($self, $date, $desc, $type, $code, $amt) = @_;
    return __x("Ongeldige datum: {date}", date => $date)."\n"
      unless $date =~ /^(\d\d\d\d)-(\d\d?)-(\d\d?)$/
	&& $1 >= 1990 && $1 < 2099
	  && $2 >= 1 && $2 <= 12
	    && $3 >= 1 && $3 <= 31; # TODO
    return __x("Datum {date} valt niet vóór het boekjaar", date => $date)."\n"
      if $self->{o}->{begindatum} && $self->{o}->{begindatum} <= $1;
    return _T("Relatietype moet \"deb\" of \"crd\" zijn")."\n"
      unless $type =~ /^crd|deb$/;
    $type = $type eq "deb";
    my $debcrd = $dbh->lookup($code, qw(Relaties rel_code rel_debcrd));
    return __x("Onbekende relatie: {rel}", rel => $code)."\n" unless defined $debcrd;
    return __x("Ongeldige relatie: {rel}", rel => $code)."\n"
      if $type  ^ $debcrd;
    return __x("Ongeldig bedrag: {amount}", amount => $amt)."\n" unless defined($amt = amount($amt));
    $self->check_open(0);
    push(@{$self->{o}->{relatie}}, [$date, $desc, $type, $code, $amt]);
    "";
}

# The actual opening process.
sub open {
    return shellhelp() unless @_ == 1;
    my ($self) = @_;
    $self->check_open(0);

    my $o = $self->{o};
    my $fail = 0;
    $fail++, warn(_T("De naam van de administratie is nog niet opgegeven")."\n")
      unless $o->{naam};
    $fail++, warn(_T("De begindatum is nog niet opgegeven")."\n")
      unless $o->{begindatum};
    $fail++, warn(_T("De BTW periode is nog niet opgegeven")."\n")
      unless $o->{btwperiode};
    if ( ($o->{balans} || $o->{relatie}) && !defined($o->{balanstotaal}) ) {
	$fail++;
	warn(_T("Het totaalbedrag van de openingsbalans is nog niet opgegeven")."\n");
    }
    if ( $o->{balanstotaal} ) {
	my $adeb = $dbh->std_acc("deb");
	my $acrd = $dbh->std_acc("crd");
	my $rdeb;
	my $rcrd;
	if ( !$o->{balans} ) {
	    $fail++;
	    warn(_T("De openingsbalans is nog niet opgegeven")."\n");
	}
	else {
	    my $debet = $o->{balanstotaal};
	    my $credit = -$debet;
	    foreach my $b ( @{$o->{balans}} ) {
		my ($acct, $amt) = @$b;
		if ( $amt >= 0 ) {
		    $debet -= $amt;
		}
		else {
		    $credit -= $amt;
		}
		$rdeb = $amt if $acct == $adeb;
		$rcrd = $amt if $acct == $acrd;
	    }
	    $fail++, warn(_T("De openingsbalans is niet in balans!")."\n".
			  __x("Totaal = {total}, residu debet = {rdeb}, residu credit = {rcrd}",
			      total => numfmt($o->{balanstotaal}),
			      rdeb => numfmt($debet),
			      rcrd => numfmt(-$credit))."\n")
	      if $debet || $credit;
	    $fail++, warn(_T("De openstaande debiteuren zijn nog niet opgegeven")."\n")
	      if defined($rdeb) && !$o->{relatie};
	    $fail++, warn(_T("De openstaande crediteuren zijn nog niet opgegeven")."\n")
	      if defined($rcrd) && !$o->{relatie};
	    $fail++, warn(_T("Er zijn openstaande posten opgegeven, maar geen corresponderende balansposten")."\n")
	      if $o->{relatie} && !(defined($rdeb) || defined($rcrd));

	    foreach my $r ( @{$o->{relatie}} ) {
		my ($date, $desc, $debcrd, $code, $amt) = @$r;
		if ( $debcrd ) {
		    $rdeb -= $amt;
		}
		else {
		    $rcrd += $amt;
		}
	    }
	    $fail++, warn(($rdeb >= 0 ?
			   __x("Er is {amt} te weinig aan openstaande {dc} opgegeven",
			       amt => numfmt($rdeb),
			       dc => lc(_T("Debiteuren"))) :
			   __x("Er is {amt} te veel aan openstaande {dc} opgegeven",
			       amt => numfmt(-$rdeb),
			       dc => lc(_T("Debiteuren"))))."\n")
	      if $rdeb;
	    $fail++, warn(($rcrd >= 0 ?
			   __x("Er is {amt} te weinig aan openstaande {dc} opgegeven",
			       amt => numfmt($rcrd),
			       dc => lc(_T("Crediteuren"))) :
			   __x("Er is {amt} te veel aan openstaande {dc} opgegeven",
			       amt => numfmt(-$rcrd),
			       dc => lc(_T("Crediteuren"))))."\n")
	      if $rcrd;
	}
    }
    return _T("DE OPENING IS NIET UITGEVOERD!")."\n" if $fail;

    my @tm = localtime(time);
    my $open = sprintf("%04d-%02d-%02d", 1900 + $tm[5], 1 + $tm[4], $tm[3]);

    $dbh->sql_exec("UPDATE Metadata".
		   " SET adm_begin = ?, adm_btwbegin = ?, adm_btwperiod = ?, adm_name = ?, adm_opened = ?",
		   $o->{begindatum} . "-01-01", , $o->{begindatum} . "-01-01", $o->{btwperiode}, $o->{naam}, $open);

    if ( $o->{balanstotaal} ) {
	foreach my $b ( @{$o->{balans}} ) {
	    my ($acct, $amt) = @$b;
	    $dbh->sql_exec("UPDATE Accounts".
			   " SET acc_balance = ?,".
			   "     acc_ibalance = ?".
			   " WHERE acc_id = ?",
			   $amt, $amt, $acct);
	}
	my $dbk_inkoop;
	my $dbk_verkoop;
	foreach my $r ( @{$o->{relatie}} ) {
	    my ($date, $desc, $debcrd, $code, $amt) = @$r;
	    my $dagboek;
	    if ( $debcrd ) {
		unless ( $dbk_verkoop ) {
		    ($dbk_verkoop) = @{$dbh->do("SELECT dbk_id FROM Dagboeken".
						" WHERE dbk_type = ?",
						DBKTYPE_VERKOOP)};
		}
		$dagboek = $dbk_verkoop;
	    }
	    else {
		unless ( $dbk_inkoop ) {
		    ($dbk_inkoop) = @{$dbh->do("SELECT dbk_id FROM Dagboeken".
					       " WHERE dbk_type = ?",
					       DBKTYPE_INKOOP)};
		}
		$dagboek = $dbk_inkoop;
		$amt = -$amt;
	    }
	    $dbh->sql_insert("Boekstukken",
			     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_paid bsk_amount)],
			     $::dbh->get_sequence("bsk_nr_0_seq"),
			     $desc, $dagboek, $date, undef, $amt);
	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_rel_code bsr_amount
				 bsr_type)],
			     1, $date,
			     $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr"),
			     $desc, $code, $amt, 9);
	}
	my $highest = $dbh->get_sequence("bsk_nr_0_seq") + 1;
	$dbh->set_sequence("bsk_nr_${dbk_inkoop}_seq", $highest)
	  if $dbk_inkoop;
	$dbh->set_sequence("bsk_nr_${dbk_verkoop}_seq", $highest)
	  if $dbk_verkoop;
    }
    $dbh->commit;
    delete($self->{o});

    require EB::Report::Balres;
    my $opts = { verbose      => $self->{verbose},
	       };

    EB::Report::Balres->new->openingsbalans($opts);
    undef;

}

sub shellhelp {
    <<EOS;
Het openen van een administratie kan slechts éénmaal gebeuren, vóór
het invoeren van de eerste mutatie.

Het openen kan een aantal opdrachten omvatten, en wordt afgesloten met
de opdracht "adm_open". Zolang deze opdracht niet is gegeven blijft de
administratie ongewijzigd.

Mogelijke opdrachten:

  adm_naam "Naam van de administratie"
  adm_btwperiode [ jaar | kwartaal | maand ]
  adm_begindatum <jaar>
		Een administratie loopt altijd van 1 januari tot en
		met 31 december van een kalenderjaar.
  adm_balanstotaal <bedrag>
		Als een balanstotaal is opgegeven, moeten er ook
		openingsbalansboekingen worden uitgevoerd met een of
                meer adm_balans opdrachten.
  adm_balans <balansrekening> <bedrag>
		De debet en credit boekingen moeten uiteindelijk
		allebei gelijk zijn aan het opgegeven balanstotaal.
		Indien er een bedrag is opgegeven voor de balansrekening
		Crediteuren of Debiteuren, dan moet er voor dit bedrag
		ook openstaande posten worden ingevoerd met een of
		meer adm_relatie opdrachten.
  adm_relatie <datum> "Omschrijving" [ crd | deb ] <code> bedrag
		Invoeren van een openstaande post uit het voorgaande
		boekjaar.
  adm_open
		Alle informatie die met de bovenstaande opdrachten is
		ingevoerd, wordt verwerkt.
EOS
}

sub check_open {
    my ($self, $open) = @_;
    $open = 1 unless defined($open);
    if ( $open && !$dbh->adm_busy ) {
	die("?"._T("De administratie is nog niet geopend")."\n");
    }
    elsif ( !$open && $dbh->adm_busy ) {
	die("?"._T("De administratie is reeds in gebruik")."\n");
    }
    1;
}

1;
