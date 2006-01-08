# $Id: Opening.pm,v 1.15 2006/01/08 18:18:37 jv Exp $

# Author          : Johan Vromans
# Created On      : Tue Aug 30 09:49:11 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Jan  6 14:40:37 2006
# Update Count    : 133
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
	set_boekjaarcode set_balans set_relatie)];
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
    #$self->check_open(0);
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

sub set_boekjaarcode {
    return shellhelp() unless @_ == 2;
    my ($self, $code) = @_;
    my $t;
    return __x("Ongeldige boekjaar-code: {year}", year => $code)."\n" unless $code =~ /^\w{1,4}$/;
    return __x("Boekjaar-code {year} bestaat al ({desc}",
	       year => $code, desc => $t)."\n"
      if $t = $dbh->lookup($code, qw(Boekjaren bky_code bky_name));
    #$self->check_open(0);
    $self->{o}->{boekjaarcode} = $code;
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
    my $self = shift;
    my ($date, $desc, $type, $code, $amt);
    my ($dbk, $bky, $nr);

    if ( $_[0] =~ /^(\w+):(\w+):(\d+)$/ ) {
	($dbk, $bky, $nr) = ($1, $2, $3);
	shift;
	($date, $desc, $code, $amt) = @_;
	my $t = $dbh->lookup($dbk, qw(Dagboeken dbk_desc dbk_type ILIKE));
	return __x("Onbekend dagboek: {dbk}", dbk => $dbk)."\n"
	  unless defined($t);
	$type = $t == DBKTYPE_VERKOOP;
    }
    else {
	($date, $desc, $type, $code, $amt) = @_;
	return _T("Relatietype moet \"deb\" of \"crd\" zijn")."\n"
	  unless $type =~ /^crd|deb$/;
	$type = $type eq "deb";
    }

    return __x("Ongeldige datum: {date}", date => $date)."\n"
      unless $date =~ /^(\d\d\d\d)-(\d\d?)-(\d\d?)$/
	&& $1 >= 1990 && $1 < 2099
	  && $2 >= 1 && $2 <= 12
	    && $3 >= 1 && $3 <= 31; # TODO
    return __x("Datum {date} valt niet vóór het boekjaar", date => $date)."\n"
      if $self->{o}->{begindatum} && $self->{o}->{begindatum} <= $1;

    my $debcrd = $dbh->lookup($code, qw(Relaties rel_code rel_debcrd));
    return __x("Onbekende relatie: {rel}", rel => $code)."\n" unless defined $debcrd;
    return __x("Ongeldige relatie: {rel}", rel => $code)."\n"
      if $type  ^ $debcrd;

    return __x("Ongeldig bedrag: {amount}", amount => $amt)."\n" unless defined($amt = amount($amt));

    $self->check_open(0);
    push(@{$self->{o}->{relatie}}, [$bky, $nr, $date, $desc, $type, $code, $amt]);
    "";
}

# The actual opening process.
sub open {
    if ( $dbh->adm_open ) {
	goto &reopen;
    }

    return shellhelp() unless @_ == 1;
    my ($self) = @_;
    $self->check_open(0);

    my $o = $self->{o};
    my $fail = 0;
    $fail++, warn(_T("De naam van de administratie is nog niet opgegeven")."\n")
      unless $o->{naam};
    $fail++, warn(_T("De begindatum is nog niet opgegeven")."\n")
      unless $o->{begindatum};

    my $gbj;
    unless ( $gbj = defined($o->{boekjaarcode}) ) {
	warn(__x("Er is geen boekjaarcode opgegeven, de waarde {val} wordt gebruikt",
		 val => $o->{boekjaarcode} = substr($o->{begindatum}, 0, 4))."\n");
	$fail++, warn(__x("Boekjaarcode \"{code}\" is reeds in gebruik",
			  code => $o->{boekjaarcode})."\n")
	  if $dbh->lookup($o->{boekjaarcode}, qw(Boekjaren bky_code bky_name));
    }
    elsif ( $o->{boekjaarcode} !~ /^\w{1,4}$/ ) {
	warn(__x("Ongeldige boekjaarcode: {code}",
		 code => $o->{boekjaarcode})."\n");
	$fail++;
    }

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
		my ($bky, $nr, $date, $desc, $debcrd, $code, $amt) = @$r;
		if ( $debcrd ) {
		    $rdeb -= $amt;
		}
		else {
		    $rcrd += $amt;
		}
		if ( defined($bky) ) {
		    my $sth = $dbh->sql_exec("SELECT bky_begin, bky_end".
					     " FROM Boekjaren".
					     " WHERE bky_code = ?", $bky);
		    my $rr = $sth->fetchrow_arrayref;
		    $sth->finish;
		    if ( defined($rr) ) {
			my ($begin, $end) = @$rr;
			if ( $date < $begin || $date > $end ) {
			    $fail++;
			    warn(_T("Boekingsdatum valt niet binnen het boekjaar")."\n");
			}
		    }
		    else {
			my $begin = substr($date, 0, 4) . "-01-01";	# TODO
			my $end   = substr($date, 0, 4) . "-12-31";	# TODO
			$dbh->sql_insert("Boekjaren",
					 [qw(bky_code bky_name bky_begin bky_end bky_btwperiod bky_opened bky_closed)],
					 $bky, "$begin - $end", $begin, $end, 0,
					 scalar(parse_date($o->{begindatum} . "-01-01", undef, -1)),
					 scalar(parse_date($o->{begindatum} . "-01-01", undef, -1)),
					);
		    }
		}
		else {
		    $bky = BKY_PREVIOUS;
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

    my $now = iso8601date();

    $dbh->sql_insert("Boekjaren",
		     [qw(bky_code bky_name bky_begin bky_end bky_btwperiod bky_opened)],
		     $o->{boekjaarcode}, $o->{naam},
		     $o->{begindatum} . "-01-01", $o->{begindatum} . "-12-31", # TODO
		     $o->{btwperiode}, $now);
    $dbh->sql_exec("UPDATE Metadata".
		   " SET adm_bky = ?, adm_btwbegin = ?",
		   $o->{boekjaarcode}, $o->{begindatum} . "-01-01");
    $dbh->sql_exec("UPDATE Boekjaren".
		   " SET bky_closed = ?, bky_end = ?".
		   " WHERE bky_code = ?",
		   scalar(parse_date($o->{begindatum} . "-01-01", undef, -1)),
		   scalar(parse_date($o->{begindatum} . "-01-01", undef, -1)),
		   BKY_PREVIOUS);

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
	    my ($bky, $nr, $date, $desc, $debcrd, $code, $amt) = @$r;

	    $nr = $dbh->get_sequence("bsk_nr_0_seq") unless defined $nr;

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
			     [qw(bsk_nr bsk_desc bsk_dbk_id bsk_date bsk_bky bsk_open bsk_amount)],
			     $nr, $desc, $dagboek, $date, $bky, $amt, $amt);
	    $dbh->sql_insert("Boekstukregels",
			     [qw(bsr_nr bsr_date bsr_bsk_id bsr_desc bsr_rel_code bsr_amount
				 bsr_type)],
			     1, $date,
			     $dbh->get_sequence("boekstukken_bsk_id_seq", "noincr"),
			     $desc, $code, $amt, 9);
	}
#	my $highest = $dbh->get_sequence("bsk_nr_0_seq") + 1;
#	$dbh->set_sequence("bsk_nr_${dbk_inkoop}_seq", $highest)
#	  if $dbk_inkoop;
#	$dbh->set_sequence("bsk_nr_${dbk_verkoop}_seq", $highest)
#	  if $dbk_verkoop;
    }
    $dbh->commit;
    delete($self->{o});
    $dbh->adm("");		# flush cache

    require EB::Report::Balres;
    my $opts = { verbose      => $self->{verbose},
		 per	      => $dbh->adm("begin"),
	       };

    EB::Report::Balres->new->openingsbalans($opts);
    undef;

}

# A new bookyear.
sub reopen {
    return shellhelp() unless @_ == 1;
    my ($self) = @_;
    $self->check_open(1);

    my $o = $self->{o};
    my $fail = 0;

    # New begin date is old + one year.
    my $y = $dbh->adm("begin");
    $y =~ s/^(\d\d\d\d)/sprintf("%04d", $1+1)/e;
    if ( $y gt iso8601date() ) {
	warn(__x("Begindatum {year} komt in de toekomst te liggen",
		 year => substr($y, 0, 4))."\n");
	$fail++;
    }

    $o->{begindatum} = $y;

    warn(_T("Er is geen nieuwe naam van de administratie opgegeven, deze blijft ongewijzigd")."\n")
      unless $o->{naam};
    warn(_T("Er is geen nieuwe BTW periode opgegeven, deze blijft ongewijzigd")."\n")
      unless $o->{btwperiode};

    if ( !defined($o->{boekjaarcode}) ) {
	warn(__x("Er is geen boekjaarcode opgegeven, de waarde {val} wordt gebruikt",
		val => $o->{boekjaarcode} = substr($o->{begindatum}, 0, 4))."\n");
    }
    return _T("HET NIEUWE BOEKJAAR IS NIET GEOPEND!")."\n" if $fail;

    my $now = iso8601date();

    $dbh->sql_insert("Boekjaren",
		     [qw(bky_code bky_name bky_begin bky_end bky_btwperiod bky_opened)],
		     $o->{boekjaarcode},
		     defined $o->{naam} ? $o->{naam} : $dbh->adm("name"),
		     $o->{begindatum}, substr($o->{begindatum}, 0, 4) . "-12-31",
		     defined $o->{btwperiode} ? $o->{btwperiode} : $dbh->adm("btwperiod"),
		     $now);

    $dbh->adm("bky", $o->{boekjaarcode});
    $dbh->adm("");		# flush cache

    # Reset boekstuknummer sequences.
    my $sth = $dbh->sql_exec("SELECT dbk_id FROM Dagboeken");
    my $max = 1;
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my $t = $dbh->get_sequence("bsk_nr_".$rr->[0]."_seq");
	$dbh->set_sequence("bsk_nr_".$rr->[0]."_seq", 1);
	$max = $t if $t > $max;
    }
    # Sequence for bookings prev period.
    $dbh->set_sequence("bsk_nr_0_seq", $max);

    $dbh->commit;
    delete($self->{o});

    undef;
}

sub shellhelp {
    <<EOS;
Het openen van een administratie kan slechts éénmaal gebeuren, vóór
het invoeren van de eerste mutatie. Het openen van een nieuw boekjaar
kan te allen tijde worden uitgevoerd, uiteraard maar één keer per
boekjaar.

Het openen kan een aantal opdrachten omvatten, en wordt afgesloten met
de opdracht "adm_open". Zolang deze opdracht niet is gegeven blijft de
administratie ongewijzigd.

Mogelijke opdrachten voor openen van een boekjaar:

  adm_btwperiode [ jaar | kwartaal | maand ]
  adm_boekjaarcode <code>
                Een code van max 4 letters en/of cijfers waarmee het
		boekjaar kan worden geïdentificeerd.
		Standaard wordt het jaartal van het boekjaar genomen.
  adm_open
		Alle informatie die met de bovenstaande opdrachten is
		ingevoerd, wordt verwerkt.

Opdrachten voor het openen van een administratie:

  adm_naam "Naam van de administratie"
  adm_btwperiode [ jaar | kwartaal | maand ]
  adm_begindatum <jaar>
		Een administratie loopt altijd van 1 januari tot en
		met 31 december van een kalenderjaar.
  adm_boekjaarcode <code>
                Een code van max 4 letters en/of cijfers waarmee het
		boekjaar kan worden geïdentificeerd.
		Standaard wordt het jaartal van het boekjaar genomen.
		De boekjaarcode is alleen relevant indien er meerdere
		boekjaren in één administratie worden bijgehouden.
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
    if ( $open && !$dbh->adm_open ) {
	die("?"._T("De administratie is nog niet geopend")."\n");
    }
    elsif ( !$open && $dbh->adm_open ) {
	die("?"._T("De administratie is reeds in gebruik")."\n");
    }
    1;
}

1;
