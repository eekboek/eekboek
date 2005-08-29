#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.12 2005/08/29 20:42:43 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Aug 29 19:05:02 2005
# Update Count    : 294
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $dbh;

package EB::Shell;

use strict;
use locale;

use base qw(EB::Shell::DeLuxe);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $opts = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };

    use EB::DB;
    $dbh ||= EB::DB->new(trace => $opts->{trace});

    _plug_cmds();

    $class->SUPER::new($opts);
}

sub prompt {
    shift->{prompt};
}

sub default {
    undef;
}

################ Subroutines ################

use EB::Globals;
use EB::DB;
use EB::Finance;

sub _plug_cmds {
    my $sth = $dbh->sql_exec("SELECT dbk_id,dbk_desc,dbk_type FROM Dagboeken");
    my $rr;
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($dbk_id, $dbk_desc, $dbk_type) = @$rr;
	no strict 'refs';
	my $dbk = lc($dbk_desc);
	*{"do_$dbk"} = sub {
	    my $self = shift;
	    $self->_add($dbk_id, @_);
	};
	*{"help_$dbk"} = sub {
	    my $self = shift;
	    $self->_help($dbk, $dbk_id, $dbk_desc, $dbk_type, @_);
	};
    }
}

sub _help {
    my ($self, $dbk, $dbk_id, $dbk_desc, $dbk_type) = @_;
    my $cmd = "$dbk"."[:nr]";
    my $text = "Toevoegen boekstuk in dagboek $dbk_desc (dagboek $dbk_id, type " .
      DBKTYPES->[$dbk_type] . ").\n\n";

    if ( $dbk_type == DBKTYPE_INKOOP ) {
	$text .= <<EOS;
  $cmd [ <datum> ] <crediteur> "Omschrijving" <bedrag> [ <rekening> ]
EOS
    }
    elsif ( $dbk_type == DBKTYPE_VERKOOP ) {
	$text .= <<EOS;
  $cmd [ <datum> ] <debiteur> "Omschrijving" <bedrag> [ <rekening> ]
EOS
    }
    elsif ( $dbk_type == DBKTYPE_BANK || $dbk_type == DBKTYPE_KAS 
	    || $dbk_type == DBKTYPE_MEMORIAAL
	  ) {
	$text .= <<EOS;
  $cmd [ <datum> ] "Omschrijving"    gevolgd door een of meer:
    std "Omschrijving" <bedrag> <rekening> -- gewone betaling
    crd <code> <bedrag>                    -- betaling van crediteur
    deb <code> <bedrag>                    -- betaling van debiteur
EOS
    }
    $text;
}

sub _state {
    my ($cur, $state) = @_;
    return !$cur unless defined($state);
    if ( $state =~ /^aan|1$/i ) {
	return 1;
    }
    if ( $state =~ /^uit|0$/i ) {
	return 0;
    }
    return !$cur;
}

sub do_trace {
    my ($self, $state) = @_;
    $self->{trace} = _state($self->{trace}, $state);

    if ( $dbh ) {
	$dbh->trace($self->{trace});
    }
    "SQL Trace: " . ($self->{trace} ? "AAN" : "UIT");
}

sub do_journal {
    my ($self, $state) = @_;
    $self->{journal} = _state($self->{journal}, $state);
    "Journal: " . ($self->{journal} ? "AAN" : "UIT");
}

sub do_confirm {
    my ($self, $state) = @_;
    $self->{confirm} = _state($self->{confirm}, $state);
    "Bevestiging: " . ($self->{confirm} ? "AAN" : "UIT");
}

sub parseline {
    my ($self, $line) = @_;

    my ($cmd, $env, @args) = $self->SUPER::parseline($line);

    if ( $cmd =~ /^(.+):(\S+)$/ ) {
	$cmd = $1;
	unshift(@args, "--nr=$2");
    }
    ($cmd, $env, @args);
}

use EB::Finance;
use EB::Journal::Text;

my $bsk;

sub _add {
    my ($self, $dagboek, @args) = @_;

    my $dagboek_type = $dbh->lookup($dagboek, qw(Dagboeken dbk_id dbk_type =));
    my $action;
    if ( $dagboek_type == DBKTYPE_INKOOP
	 || $dagboek_type == DBKTYPE_VERKOOP ) {
	require EB::Booking::IV;
	$action = EB::Booking::IV->new;
    }
    elsif ( $dagboek_type == DBKTYPE_BANK
	    || $dagboek_type == DBKTYPE_KAS
	    || $dagboek_type == DBKTYPE_MEMORIAAL) {
	require EB::Booking::BKM;
	$action = EB::Booking::BKM->new;
    }
    else {
      die("Onbekend of verkeerd dagboek: $dagboek [$dagboek_type]\n");
    }

    my $opts = { dagboek      => $dagboek,
		 dagboek_type => $dagboek_type,
		 journal      => $self->{journal},
		 verbose      => $self->{verbose},
	       };

    my $args = \@args;
    parse_args($args,
	       [ 'boekstuk|nr=s',
		 'journal!',
		 'verbose!',
		 'confirm!',
		 ( $dagboek_type == DBKTYPE_BANK
		   || $dagboek_type == DBKTYPE_KAS ) ? ( 'saldo=s' ) : (),
		 'trace!',
	       ], $opts);

    $bsk = $action->perform($args, $opts);
    $bsk ? "Boekstuk: $bsk" : "";
}

sub do_journaal {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { dagboeken    => 0,
		 detail       => 1,
		 verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'dagboeken',
		 'detail!',
		 'verbose!',
		 'trace!',
	       ], $opts);

    $b = shift(@args) if @args;
    undef $b if $b && lc($b) eq "all";
    $opts->{select} = $b;
    EB::Journal::Text->new->journal($opts);
    undef;
}

sub help_journaal {
    <<EOS;
Print journaalposten.

  journaal all           -- alle posten
  journaal <id>          -- alleen boekstuknummer met dit id
  journaal <dagboek>     -- alle journaalposten van dit dagboek
  journaal <dagboek>:<n> -- boekstuk n van dit dagboek
  journaal               -- journaalposten van de laatste boeking
EOS
}

sub do_balans {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = { verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'verbose!',
		 'trace!',
	       ], $opts);
    warn("?Te veel argumenten voor deze opdracht\n"), return if @args;
    EB::Report::Balres->new->balans($opts);
    undef;
}

sub help_balans {
    <<EOS;
Print de balansrekening.

Opties:
  <geen>        Balans op grootboekrekening
  --verdicht    verdicht, gedetailleerd
  --detail=N    verdicht, mate van detail N = 0, 1 of 2
EOS
}

sub do_result {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = { verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'verbose!',
		 'trace!',
	       ], $opts);
    warn("?Te veel argumenten voor deze opdracht\n"), return if @args;
    EB::Report::Balres->new->result($opts);
    undef;
}

sub help_result {
    <<EOS;
Print de resultatenrekening.

Opties:
  <geen>        Resultatenrekening op grootboekrekening
  --verdicht    verdicht, gedetailleerd
  --detail=N    verdicht, mate van detail N = 0, 1 of 2
EOS
}

sub do_proefensaldibalans {
    my ($self, @args) = @_;
    require EB::Report::Proof;

    my $opts = { verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'verbose!',
		 'trace!',
	       ], $opts);
    warn("?Te veel argumenten voor deze opdracht\n"), return if @args;
    EB::Report::Proof->new->proefensaldibalans($opts);
    undef;
}

sub help_proefensaldibalans {
    <<EOS;
Print de Proef- en Saldibalans.

Opties:
  <geen>        Proef- en Saldibalans op grootboekrekening
  --verdicht    verdicht, gedetailleerd
  --detail=N    verdicht, mate van detail N = 0, 1 of 2
EOS
}

sub do_grootboek {
    my ($self, @args) = @_;
    require EB::Report::Grootboek;

    my $opts = { detail       => 2,
		 verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'detail=i',
		 'verbose!',
		 'trace!',
	       ], $opts);

    EB::Report::Grootboek->new->perform($opts);
    undef;
}

sub help_grootboek {
    <<EOS;
Print het Grootboek

  grootboek 
EOS
}

sub do_dagboeken {
    my ($self, @args) = @_;
    my $rr;
    my $sth = $dbh->sql_exec("SELECT dbk_id, dbk_desc, dbk_type, dbk_acc_id".
			       " FROM Dagboeken".
			       " ORDER BY dbk_id");
    my $fmt = "%2s  %-16s %-12s %5s\n";
    my $text = sprintf($fmt, "Nr", "Naam", "Type", "Rekening");
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($dbk_id, $dbk_desc, $dbk_type, $dbk_acct) = @$rr;
	$dbk_acct ||= "n.v.t.";
	$text .= sprintf($fmt, $dbk_id, $dbk_desc, DBKTYPES->[$dbk_type], $dbk_acct);
    }
    $text;
}

sub help_dagboeken {
    <<EOS;
Print een lijstje van gebruikte dagboeken.
EOS
}

sub do_relatie {
    my $self = shift;
    use EB::Relation;
    EB::Relation->new->add(@_);
}

sub help_relatie {
    <<EOS;
Aanmaken nieuwe relatie.

  relatie <code> "Omschrijving" <rekening> [ <country-code> ]
EOS
}

sub do_database { "Database: " . $ENV{EB_DB_NAME} }
sub intro {
    my $self = $_[0];
    goto &do_database if $self->{interactive};
    undef;
}
sub outro { undef }
sub postcmd { shift; $dbh->rollback; shift }

sub do_btwaangifte {
    my $self = shift;
    use EB::BTWAangifte::Text;
    EB::BTWAangifte::Text->new->perform({periode => shift});
    undef;
}

sub help_btwaangifte {
    <<EOS;
Print de BTW aangifte.

  btwaangifte [ periode ]

Aangifteperiode kan zijn:

  j            het gehele jaar
  h1 h2        1e/2e helft van het jaar (ook: s1, ...)
  k1 k2 k3 k4  1e/2e/3e/4e kwartaal (ook: q1, ...)
EOS
}

use Getopt::Long;

sub parse_args {
    my ($args, $ctl, $opts) = @_;
    local(*ARGV) = $args;
    Getopt::Long::Configure("prefix_pattern=--");
    my $ret = GetOptions($opts, @$ctl);
    $ret;
}

sub _nyi {
    "Opdracht is nog niet geïmplementeerd";
}

sub do_adm_naam {
    goto &help_adm_open unless @_ == 2;
    my ($self, $naam) = @_;
    $self->check_open(0);
    $self->{o}->{naam} = $naam;
    "";
}

sub do_adm_btwperiode {
    goto &help_adm_open unless @_ == 2;
    my ($self, $per) = @_;
    return "Ongeldige BTW periode: $per\n"
      unless $per =~ /^(jaar|kwartaal|maand)$/i;
    $self->check_open(0);
    $self->{o}->{btwperiode} = 1 if lc($per) eq "jaar";
    $self->{o}->{btwperiode} = 4 if lc($per) eq "kwartaal";
    $self->{o}->{btwperiode} = 12 if lc($per) eq "maand";
    ""
}

sub do_adm_begindatum {
    goto &help_adm_open unless @_ == 2;
    my ($self, $jaar) = @_;
    return "Ongeldige jaar-aanduiding: $jaar\n" unless $jaar =~ /^\d+$/
      && $jaar >= 1990 && $jaar < 2099;	# TODO
    $self->check_open(0);
    $self->{o}->{begindatum} = $jaar;
    "";
}

sub do_adm_balanstotaal {
    goto &help_adm_open unless @_ == 2;
    my ($self, $amt) = @_;
    return "Ongeldig bedrag: $amt\n" unless defined($amt = amount($amt));
    $self->check_open(0);
    $self->{o}->{balanstotaal} = $amt;
    "";
}

sub do_adm_balans {
    goto &help_adm_open unless @_ == 3;
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

sub do_adm_relatie {
    goto &help_adm_open unless @_ == 6;
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

sub do_adm_open {
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

sub help_adm_naam         { goto &help_adm_open }
sub help_adm_btwperiode   { goto &help_adm_open }
sub help_adm_begindatum   { goto &help_adm_open }
sub help_adm_balanstotaal { goto &help_adm_open }
sub help_adm_balans       { goto &help_adm_open }
sub help_adm_relatie      { goto &help_adm_open }

sub help_adm_open {
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
