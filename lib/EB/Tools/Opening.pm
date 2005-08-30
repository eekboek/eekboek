# $Id: Opening.pm,v 1.5 2005/08/30 08:38:02 jv Exp $

package main;

our $dbh;

package EB::Tools::Opening;
use strict;
use EB::Globals;
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
    return "Ongeldige BTW periode: $per\n"
      unless $per =~ /^(jaar|kwartaal|maand)$/i;
    $self->check_open(0);
    $self->{o}->{btwperiode} = 1 if lc($per) eq "jaar";
    $self->{o}->{btwperiode} = 4 if lc($per) eq "kwartaal";
    $self->{o}->{btwperiode} = 12 if lc($per) eq "maand";
    ""
}

sub set_begindatum {
    return shellhelp() unless @_ == 2;
    my ($self, $jaar) = @_;
    return "Ongeldige jaar-aanduiding: $jaar\n" unless $jaar =~ /^\d+$/
      && $jaar >= 1990 && $jaar < 2099;	# TODO
    $self->check_open(0);
    $self->{o}->{begindatum} = $jaar;
    "";
}

sub set_balanstotaal {
    return shellhelp() unless @_ == 2;
    my ($self, $amt) = @_;
    return "Ongeldig bedrag: $amt\n" unless defined($amt = amount($amt));
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
    return "Onbekende grootboekrekening: $acct\n"
      unless defined($rr);
    my $balres = $rr->[0];
    return "Grootboekrekening $acct is geen balansrekening\n"
      unless $balres;
    my $debcrd;
    if ( $amt =~ /^(.*)([DC])/ ) {
	$amt = $1;
	$debcrd = $2 eq "D";
    }
    else {
	$debcrd = $rr->[1];
    }
    return "Ongeldig bedrag: $amt\n" unless defined($amt = amount($amt));
    $self->check_open(0);
    push(@{$self->{o}->{balans}}, [$acct, $debcrd ? $amt : -$amt]);
    "";
}

sub set_relatie {
    return shellhelp() unless @_ == 6;
    my ($self, $date, $desc, $type, $code, $amt) = @_;
    return "Ongeldige datum: $date\n"
      unless $date =~ /^(\d\d\d\d)-(\d\d?)-(\d\d?)$/
	&& $1 >= 1990 && $1 < 2099
	  && $2 >= 1 && $2 <= 12
	    && $3 >= 1 && $3 <= 31; # TODO
    return "Datum $date valt niet vóór het boekjaar\n"
      if $self->{o}->{begindatum} && $self->{o}->{begindatum} <= $1;
    return "Relatietype moet \"deb\" of \"crd\" zijn\n"
      unless $type =~ /^crd|deb$/;
    $type = $type eq "deb";
    my $debcrd = $dbh->lookup($code, qw(Relaties rel_code rel_debcrd));
    return "Onbekende relatie: $code\n" unless defined $debcrd;
    return "Ongeldige relatie: $code\n"
      if $type  ^ $debcrd;
    return "Ongeldig bedrag: $amt\n" unless defined($amt = amount($amt));
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
    $fail++, warn("De naam van de administratie is nog niet opgegeven\n")
      unless $o->{naam};
    $fail++, warn("De begindatum is nog niet opgegeven\n")
      unless $o->{begindatum};
    $fail++, warn("De BTW periode is nog niet opgegeven\n")
      unless $o->{btwperiode};
    if ( ($o->{balans} || $o->{relatie}) && !defined($o->{balanstotaal}) ) {
	$fail++;
	warn("Het totaalbedrag van de openingsbalans is nog niet opgegeven\n");
    }
    if ( $o->{balanstotaal} ) {
	my $adeb = $dbh->std_acc("deb");
	my $acrd = $dbh->std_acc("crd");
	my $rdeb;
	my $rcrd;
	if ( !$o->{balans} ) {
	    $fail++;
	    warn("De openingsbalans is nog niet opgegeven\n");
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
	    $fail++, warn("De openingsbalans is niet in balans!\n".
			  "Totaal = " . numfmt($o->{balanstotaal}) .
			  ", residu debet = " . numfmt($debet) .
			  ", residu credit = " . numfmt(-$credit) .
			  "\n")
	      if $debet || $credit;
	    $fail++, warn("De openstaande debiteuren zijn nog niet opgegeven\n")
	      if defined($rdeb) && !$o->{relatie};
	    $fail++, warn("De openstaande crediteuren zijn nog niet opgegeven\n")
	      if defined($rcrd) && !$o->{relatie};
	    $fail++, warn("Er zijn openstaande posten opgegeven, maar geen corresponderende balansposten\n")
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
	    $fail++, warn("Er is ".numfmt(abs($rdeb))." te ".
			  ($rdeb >= 0 ? "weinig" : "veel"). " aan openstaande".
			  " debiteuren opgegeven\n")
	      if $rdeb;
	    $fail++, warn("Er is ".numfmt(abs($rcrd))." te ".
			  ($rcrd >= 0 ? "weinig" : "veel"). " aan openstaande".
			  " crediteuren opgegeven\n")
	      if $rcrd;
	}
    }
    return "DE OPENING IS NIET UITGEVOERD!\n" if $fail;

    my @tm = localtime(time);
    my $open = sprintf("%04d-%02d-%02d", 1900 + $tm[5], 1 + $tm[4], $tm[3]);

    $dbh->sql_exec("UPDATE Metadata".
		   " SET adm_begin = ?, adm_btwperiod = ?, adm_name = ?, adm_opened = ?",
		   $o->{begindatum} . "-01-01", $o->{btwperiode}, $o->{naam}, $open);

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
	die("Administratie is nog niet geopend\n");
    }
    elsif ( !$open && $dbh->adm_busy ) {
	die("Administratie is reeds in gebruik\n");
    }
    1;
}

1;
