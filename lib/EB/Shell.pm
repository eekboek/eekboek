#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.46 2005/12/12 10:53:01 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Dec 12 11:46:04 2005
# Update Count    : 617
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $dbh;

package EB::Shell;

use strict;

my $bky;			# current boekjaar (if set)

use base qw(EB::Shell::DeLuxe);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $opts = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };

    _plug_cmds();

    my $self = $class->SUPER::new($opts);

    if ( $self->{interactive} ) {
	$self->term->Attribs->{completion_function} = sub { $self->eb_complete(@_) };
    }
    if ( defined $self->{boekjaar} ) {
	$self->do_boekjaar($self->{boekjaar});
    }
    $self;
}

sub prompt {
    my $t = $ENV{EB_DB_NAME};
    $t =~ s/^eekboek_//;
    $t = shift->{prompt} . " [$t";
    $t .= ":$bky" if defined $bky;
    $t . "] ";
}

sub default {
    undef;
}

sub intro {
    my $self = $_[0];
    if ( $self->{interactive} ) {
	do_database();
	bky_msg();
    }
    undef;
}
sub outro { undef }
sub postcmd { shift; $dbh->rollback; shift }

sub bky_msg {
    my $sth = $dbh->sql_exec("SELECT bky_code".
			     " FROM Boekjaren".
			     " WHERE bky_end < ?".
			     " AND bky_closed IS NULL".
			     " ORDER BY bky_begin",
			     defined $bky ?
			     $dbh->lookup($bky, qw(Boekjaren bky_code bky_begin)) :
			     $dbh->adm("begin"));
    while ( my $rr = $sth->fetchrow_arrayref ) {
	warn("!".__x("Pas op! Boekjaar {bky} is nog niet afgesloten",
		     bky => $rr->[0])."\n");
    }
}

my $dbk_pat;
my $dbk_i_pat;
my $dbk_v_pat;
my $dbk_bkm_pat;

sub eb_complete {
    my ($self, $word, $line, $pos) = @_;
    my $i = index($line, ' ');
    #warn "\nCompleting '$word' in '$line' (pos $pos, space $i)\n";
    my $pre = substr($line, 0, $pos);
    #warn "\n[$pre][", substr($line, $pos), "]\n";

    if ( $i < 0 || $i > $pos-1 || $pre =~ /^help\s+$/ ) {
	my @extra;
	@extra = qw(rapporten periodes) if $pre =~ /^help\s+$/;
	my @a = grep { /^$word/ } (@extra, $self->completions);
	if ( @a ) {
	    return $a[0] if @a == 1;
	    $self->term->display_match_list([$a[0],@a], $#a+1, -1);
	    print STDERR ("$line");
	}
	return;
    }
    if ( $word =~ /^\d+$/ )  {
	my $sth = $dbh->sql_exec("SELECT acc_id,acc_desc from Accounts".
				 " WHERE acc_id LIKE ?".
				 " ORDER BY acc_id", "$word%");
	return () if $sth->rows == 0;
	return ($sth->fetchrow_arrayref->[0]) if $sth->rows == 1;
	print STDERR ("\n");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    printf STDERR ("%9d  %s\n", @$rr);
	}
	print STDERR ("$line");
	return ();
    }
    my $t;
    if ( ($word =~ /^[[:alpha:]]/ || $word eq "?")
	 && (($pre =~ /^\s*(?:$dbk_bkm_pat).*\s(crd|deb)\s+$/ and $t = $1)
	     || ($pre =~ /^\s*(?:$dbk_i_pat)(?::\S+)?(?:\s+[0-9---]+)?\s*$/ and $t = "deb")
	     || ($pre =~ /^\s*(?:$dbk_v_pat)(?::\S+)?(?:\s+[0-9---]+)?\s*$/ and $t = "crd"))) {
	$word = "" if $word eq "?";
	my $sth = $dbh->sql_exec("SELECT rel_code,rel_desc from Relaties".
				 " WHERE rel_code LIKE ?".
				 " AND " . ($t eq "deb" ? "" : "NOT ") . "rel_debcrd".
				 " ORDER BY rel_code", "$word%");
	return () if $sth->rows == 0;
	if ( $sth->rows == 1 && $word ne "" ) {
	    $t = $sth->fetchrow_arrayref->[0];
	    return ($t);
	}
	print STDERR ("\n");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    printf STDERR ("  %s  %s\n", @$rr);
	}
	print STDERR ("$line");
	return ();
    }
    #warn "\n[$pre][", substr($line, $pos), "]\n";
    return ();
}

sub parseline {
    my ($self, $line) = @_;
    $line =~ s/;\s*$//;
    my ($cmd, $env, @args) = $self->SUPER::parseline($line);

    if ( $cmd =~ /^(.+):(\S+)$/ ) {
	$cmd = $1;
	unshift(@args, "--nr=$2");
    }
    ($cmd, $env, @args);
}

################ Subroutines ################

use EB;
use EB::Tools::Opening;

# Standard options for report generating backends.
my @outopts;
INIT { @outopts = qw(html csv text output=s page=i) }

# Plug in some commands dynamically.
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
	if ( $dbk_type == DBKTYPE_INKOOP ) {
	    $dbk_v_pat .= lc($dbk_desc)."|";
	}
	elsif ( $dbk_type == DBKTYPE_VERKOOP ) {
	    $dbk_i_pat .= lc($dbk_desc)."|";
	}
	else {
	    $dbk_bkm_pat .= lc($dbk_desc)."|";
	}
    }

    # Opening (adm_...) commands.
    foreach my $adm ( @{EB::Tools::Opening->commands} ) {
	my $cmd = $adm;
	$cmd =~ s/^set_//;
	no strict 'refs';
	*{"do_adm_$cmd"} = sub {
	    (shift->{o} ||= EB::Tools::Opening->new)->$adm(@_);
	};
	*{"help_adm_$cmd"} = sub {
	    (shift->{o} ||= EB::Tools::Opening->new)->shellhelp(@_);
	};
    }

    $dbk_pat = $dbk_i_pat.$dbk_v_pat.$dbk_bkm_pat;
    chop foreach ($dbk_pat, $dbk_i_pat, $dbk_v_pat, $dbk_bkm_pat);
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
    std [ <datum> ] "Omschrijving" <bedrag> <rekening> -- gewone betaling
    crd [ <datum> ] <code> <bedrag>                    -- betaling van crediteur
    deb [ <datum> ] <code> <bedrag>                    -- betaling van debiteur
EOS
    }
    $text;
}

################ Global toggles ################

sub _state {
    my ($cur, $state) = @_;
    return !$cur unless defined($state);
    my $on = _T("aan");
    my $off = _T("uit");
    return 1 if $state =~ /^$on|1$/i;
    return 0 if $state =~ /^$off|0$/i;
    return !$cur;
}

sub do_trace {
    my ($self, $state) = @_;
    $self->{trace} = _state($self->{trace}, $state);

    if ( $dbh ) {
	$dbh->trace($self->{trace});
    }
    __x("SQL Trace: {state}", state => uc($self->{trace} ? _T("aan") : _T("uit")));
}

sub do_journal {
    my ($self, $state) = @_;
    $self->{journal} = _state($self->{journal}, $state);
    __x("Journal: {state}", state => uc($self->{journal} ? _T("aan") : _T("uit")));
}

sub do_confirm {
    my ($self, $state) = @_;
    $self->{confirm} = _state($self->{confirm}, $state);
    __x("Bevestiging: {state}", state => uc($self->{confirm} ? _T("aan") : _T("uit")));
}

sub do_database {
    my ($self, @args) = @_;
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
    __x("Database: {db}", db => $ENV{EB_DB_NAME})
}

################ Service ################

sub argcnt($$;$) {
    my ($cnt, $min, $max) = @_;
    $max = $min unless defined $max;
    return 1 if $cnt >= $min && $cnt <= $max;
    warn("?"._T("Te weinig argumenten voor deze opdracht")."\n") if $cnt < $min;
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n") if $cnt > $max;
    undef;
}

################ Bookings ################

my $bsk;			# current/last boekstuk

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
      die("?".__x("Onbekend of verkeerd dagboek: {dbk} [{type}]",
		  dbk => $dagboek, type => $dagboek_type)."\n");
    }

    my $opts = { dagboek      => $dagboek,
		 dagboek_type => $dagboek_type,
		 d_boekjaar   => $bky || $dbh->adm("bky"),
		 journal      => $self->{journal},
		 totaal	      => undef,
		 confirm      => $self->{confirm},
	       };

    my $args = \@args;
    return unless
    parse_args($args,
	       [ 'boekstuk|nr=s',
		 'boekjaar=s',
		 'journal!',
		 'totaal=s',
		 'confirm!',
		 ( $dagboek_type == DBKTYPE_BANK
		   || $dagboek_type == DBKTYPE_KAS ) ? ( 'saldo=s' ) : (),
	       ], $opts);

    $opts->{boekjaar} = $opts->{d_boekjaar} unless defined $opts->{boekjaar};
    $bsk = $action->perform($args, $opts);
    $bsk ? $bsk =~ /^\w+:\d+/ ? __x("Boekstuk: {bsk}", bsk => $bsk) : $bsk : "";
}

################ Reports ################

sub do_journaal {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { detail       => 1,
		 d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Journal;

    return unless
    parse_args(\@args,
	       [ 'detail!',
		 'totaal' => sub { $opts->{detail} = 0 },
		 'boekjaar=s',
		 'periode=s' => sub { periode_arg($opts, @_) },
		 EB::Report::GenBase->backend_options(EB::Report::Journal::, $opts),
	       ], $opts);

    $b = shift(@args) if @args;
    undef $b if $b && lc($b) eq "all";
    $opts->{select} = $b;
    EB::Report::Journal->new->journal($opts);
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

Opties

  --[no]detail           -- mate van detail, standaard is met details
  --totaal               -- alleen het totaal (detail = 0)
  --periode=XXX          -- alleen over deze periode

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_balans {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'boekjaar=s',
		 'per=s' => sub { date_arg($opts, @_) },
		 EB::Report::GenBase->backend_options(EB::Report::Balres::, $opts),
	       ], $opts);
    return unless argcnt(@args, 0);
    EB::Report::Balres->new->balans($opts);
    undef;
}

sub help_balans {
    <<EOS;
Print de balansrekening.

Opties:
  <geen>          Balans op grootboekrekening
  --verdicht      Verdicht, gedetailleerd
  --detail=N      Verdicht, mate van detail N = 0, 1 of 2
  --per=XXX       Selecteer einddatum
  --boekjaar=XX   Selecteer boekjaar
EOS
}

sub do_result {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'boekjaar=s',
		 'periode=s' => sub { periode_arg($opts, @_) },
		 EB::Report::GenBase->backend_options(EB::Report::Balres::, $opts),
	       ], $opts);
    return unless argcnt(@args, 0);
    EB::Report::Balres->new->result($opts);
    undef;
}

sub help_result {
    <<EOS;
Print de resultatenrekening.

Opties:
  <geen>           Resultatenrekening op grootboekrekening
  --verdicht       Verdicht, gedetailleerd
  --detail=N       Verdicht, mate van detail N = 0, 1 of 2
  --periode=XXX    Selecteer periode
  --boekjaar=XX    Selecteer boekjaar
EOS
}

sub do_proefensaldibalans {
    my ($self, @args) = @_;
    require EB::Report::Proof;

    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 EB::Report::GenBase->backend_options(EB::Report::Proof::, $opts),
	       ], $opts);
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
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
		 d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'periode=s' => sub { periode_arg($opts, @_) },
		 'boekjaar=s',
		 EB::Report::GenBase->backend_options(EB::Report::Grootboek::, $opts),
	       ], $opts);

    my $fail;
    foreach ( @args ) {
	if ( /^\d+$/ ) {
	    if ( defined($opts->{select}) ) {
		$opts->{select} .= ",$_";
	    }
	    else {
		$opts->{select} = $_;
	    }
	    next;
	}
	warn("?".__x("Ongeldig rekeningnummer: {acct}",
		     acct => $_)."\n");
	$fail++;
    }
    return if $fail;
    EB::Report::Grootboek->new->perform($opts);
    undef;
}

sub help_grootboek {
    <<EOS;
Print het Grootboek, of een selectie daaruit.

  grootboek [ <rek> ... ]

Opties:

  --detail=N            -- mate van detail, N=0,1,2 (standaard is 2)
  --periode=XXX         -- alleen over deze periode
EOS
}

sub do_dagboeken {
    my ($self, @args) = @_;
    my $rr;
    my $sth = $dbh->sql_exec("SELECT dbk_id, dbk_desc, dbk_type, dbk_acc_id".
			       " FROM Dagboeken".
			       " ORDER BY dbk_id");
    my $fmt = "%2s  %-16s %-12s %5s\n";
    my $text = sprintf($fmt, _T("Nr"), _T("Naam"), _T("Type"), _T("Rekening"));
    while ( $rr = $sth->fetchrow_arrayref ) {
	my ($dbk_id, $dbk_desc, $dbk_type, $dbk_acct) = @$rr;
	$dbk_acct ||= _T("n.v.t.");
	$text .= sprintf($fmt, $dbk_id, $dbk_desc, DBKTYPES->[$dbk_type], $dbk_acct);
    }
    $text;
}

sub help_dagboeken {
    <<EOS;
Print een lijstje van beschikbare dagboeken.
EOS
}

sub do_btwaangifte {
    my ($self, @args) = @_;
    my $close = 0;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    use EB::Report::BTWAangifte;

    return unless
    parse_args(\@args,
	       [ EB::Report::GenBase->backend_options(EB::Report::BTWAangifte::, $opts),
		 "definitief" => sub { $close = 1 },
	       ], $opts)
      or goto &help_btwaangifte;

    if ( lc($args[-1]) eq "definitief" ) {
	$close = 1;
	pop(@args);
    }
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args > 1;
    $opts->{close} = $close;
    $opts->{periode} = $args[0] if @args;
    EB::Report::BTWAangifte->new($opts)->perform($opts);
    undef;
}

sub help_btwaangifte {
    <<EOS;
Print de BTW aangifte.

  btwaangifte [ opties ] [ periode ]

Aangifteperiode kan zijn:

  j jaar       het gehele jaar
  k1 k2 k3 k4  1e/2e/3e/4e kwartaal (ook: q1, ...)
  1 2 3 ... jan feb ... januari ...  maand

Standaard is de eerstvolgende periode waarover nog geen aangifte is
gedaan.

Opties:

  --definitief  de BTW periode wordt afgesloten. Er zijn geen boekingen
                in deze periode meer mogelijk.
                Uit historische overwegingen kan dit ook door het
                woord "definitief" achter de opdracht te plaatsen.

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_openstaand {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Open;

    return unless
    parse_args(\@args,
	       [ EB::Report::GenBase->backend_options(EB::Report::Open::, $opts),
		 'per=s' => sub { date_arg($opts, @_) },
	       ], $opts);

    return unless argcnt(@args, 0);
    EB::Report::Open->new->perform($opts);
}

sub help_openstaand {
    <<EOS;
Toont een overzicht van openstaande posten.

  openstaand [ opties ]

Opties:

  --per XXX      t/m einddatum  ***WERKT NOG NIET***

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub help_rapporten {
    <<EOS;
Alle rapport-producerende opdrachten kennen de volgende opties:

  --periode=XXX   De periode waarover de rapportage moet plaatsvinden.
                  (Niet voor elke opdracht relevant.)
                  Zie "help periodes" voor details.
  --output=XXX    Produceer het rapport in dit bestand
                  Uitvoertype is afhankelijk van bestandsextensie, b.v.
                  xx.html levert HTML, xx.txt een tekstbestand,
                  xx.csv een CSV, etc.
  --gen-XXX       Forceer uitvoertype (html, csv, text, ...)
                  Afhankelijk van de beschikbare uitvoertypes zijn ook
                  de kortere opties --html, --csv en --text toegestaan.
		  (Let op: --gen-XXX, niet --gen=XXX)
  --page=NNN      Paginagrootte voor tekstrapporten.
EOS
}

sub help_periodes {
    <<EOS;
De volgende periode-aanduidingen zijn mogelijk:

   2005-04-01 - 2005-07-31
   01-04-2005 - 31-07-2005
   01-04 - 31-07-2005
   01-04 - 31-07  (vooropgesteld dat het boekjaar 2005 is)
   1 april 2005 - 31 juli 2005 (en varianten)
   1 apr 2005 - 31 jul 2005 (en varianten)
   apr - jul
   k2  (tweede kwartaal)
   april 2003 (01-04-2003 - 30-04-2003)
   april  (01-04 - 30-04 boekjaar)
   m4  (vierde maand)
   jaar (gehele boekjaar)
EOS
}

################ Relations ################

sub do_relatie {
    my ($self, @args) = @_;

    my $opts = {
	       };

    return unless
    parse_args(\@args,
	       [ 'dagboek=s',
		 'btw=s',
	       ], $opts)
      or goto &help_relatie;

    warn("?"._T("Ongeldig aantal argumenten voor deze opdracht")."\n"), return if @args % 3;

    use EB::Relation;

    while ( @args ) {
	my @a = splice(@args, 0, 3);
	my $res = EB::Relation->new->add(@a, $opts);
	warn("$res\n") if $res;
    }
}

sub help_relatie {
    <<EOS;
Aanmaken een of meer nieuwe relaties.

  relatie [ opties ] { <code> "Omschrijving" <rekening> } ...

Opties:

  --dagboek=XXX  -- selecteer dagboek voor deze relatie
  --btw=XXX      -- BTW type: normaal, verlegd, intra, extra
                    *** BTW type 'verlegd' wordt nog niet ondersteund ***
                    *** BTW type 'intra' wordt nog niet geheel ondersteund ***
EOS
}

################ Miscellaneous ################

sub do_boekjaar {
    my ($self, @args) = @_;
    return unless argcnt(@args, 1);
    my $b = $dbh->lookup($args[0], qw(Boekjaren bky_code bky_name));
    warn("?".__x("Onbekend boekjaar: {code}", code => $args[0])."\n"), return unless defined $b;
    $bky = $args[0];
    bky_msg();
    __x("Boekjaar voor deze sessie: {bky} ({desc})", bky => $bky, desc => $b);
}

sub help_boekjaar {
    <<EOS;
Gebruik voor navolgende opdrachten het opgegeven boekjaar.

  boekjaar <code>
EOS
}

sub do_dump_schema {
    my ($self, @args) = @_;

    my $opts = { sql => 0,
	       };

    return unless
    parse_args(\@args,
	       [ 'sql!',
	       ], $opts)
      or goto &help_dump_schema;

    require EB::Tools::Schema;

    if ( $opts->{sql} ) {
	EB::Tools::Schema->dump_sql(@args);
    }
    else {
	EB::Tools::Schema->dump_schema;
    }
    "";
}

sub help_dump_schema {
    <<EOS;
Reproduceert het schema van de huidige database en schrijft deze naar
standaard uitvoer.

  dump_schema
EOS
}

sub do_verwijder {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'boekjaar=s',
	       ], $opts);
    $opts->{boekjaar} = $opts->{d_boekjaar} unless defined $opts->{boekjaar};

    use EB::Booking::Delete;
    @args = ($bsk) if $bsk && !@args;
    return _T("Gaarne een boekstuk") unless @args == 1;
    my $cmd;
    my $id = shift(@args);
    if ( $self->{interactive} ) {
	(my $xid, my $id, my $err) = $dbh->bskid($id, $opts->{boekjaar});
	unless ( defined($id) ) {
	    warn("?".$err."\n");
	    return;
	}
	$cmd = EB::Booking::Decode->decode($id, { trail => 1, bsknr => 1, single => 1 });
    }
    my $res = EB::Booking::Delete->new->perform($id, $opts);
    if ( $self->{interactive} && $res !~ /^[?!]/ ) {	# no error
	$self->term->addhistory($cmd);
    }
    $res;
}

sub help_verwijder {
    <<EOS;
Verwijdert een boekstuk. Het boekstuk mag niet in gebruik zijn.

  verwijder [ <opties> ] <boekstuk>

Opties:

  --boekjaar XXX    selekteer boekjaar
EOS
}

sub do_toon {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { verbose      => 0,
		 bsknr        => 1,
		 d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    return unless
    parse_args(\@args,
	       [ 'btw!',
		 'bsknr!',
		 'boekjaar=s',
		 'verbose!',
		 'trace!',
	       ], $opts);

    $opts->{trail} = !$opts->{verbose};
    $opts->{boekjaar} = $opts->{d_boekjaar} unless defined $opts->{boekjaar};

    use EB::Booking::Decode;
    @args = ($bsk) if $bsk && !@args;
    return _T("Gaarne een boekstuk") unless @args == 1;
    my ($id, $dbs, $err) = $dbh->bskid(shift(@args), $opts->{boekjaar});
    unless ( defined($id) ) {
	warn("?".$err."\n");
	return;
    }
    my $res = EB::Booking::Decode->decode($id, $opts);
    if ( $self->{interactive} && $res !~ /^[?!]/ && $opts->{trail} ) {	# no error
	my $t = $res;
	$t =~ s/\s+\\\s+/ /g;
	$self->term->addhistory($t);
    }
    $res;
}

sub help_toon {
    <<EOS;
Toon een boekstuk in tekst- of commando-vorm.

  toon [opties] <boekstuk>

Opties:

  --boekjaar XXX  selekteer boekjaar
  --verbose       toon in uitgebreide (tekst) vorm
  --btw           vermeld altijd BTW codes
  --bsknr         vermeld altijd het boekstuknummer (default)
EOS
}

sub do_jaareinde {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky,
		 journal    => 1,
	       };

    return unless
    parse_args(\@args,
	       [ 'boekjaar=s',
		 'definitief',
		 'verwijder',
		 'journal!',
	       ], $opts);

    return _T("Opties \"definitief\" en \"verwijder\" sluiten elkaar uit")
      if $opts->{definitief} && $opts->{verwijder};
    return unless argcnt(@args, 0);
    require EB::Tools::Einde;
    EB::Tools::Einde->new->perform(\@args, $opts);
}

sub help_jaareinde {
    <<EOS;
Sluit het boekjaar af. De BTW rekeningen worden afgeboekt, en de
winst/verlies wordt verrekend met de daartoe aangewezen
balansrekening.

  jaareinde [ opties ]

Opties:

  --boekjaar=XXX   Sluit het opgegeven boekjaar af
  --definitief     Sluit het boekjaar definitief af. Er zijn dan geen
                   boekingen meer mogelijk.
  --verwijder      Verwijder een tentatieve jaarafsluiting.
EOS
}

################ Argument parsing ################

use Getopt::Long;

sub parse_args {
    my ($args, $ctl, $opts) = @_;
    local(*ARGV) = $args;
    Getopt::Long::Configure("prefix_pattern=--");
    my $ret = GetOptions($opts, @$ctl);
    $ret;
}

sub periode_arg {
    my ($opts, $name, $value) = @_;
    if ( my $p = parse_date_range($value, substr($dbh->adm("begin"),0,4)) ) {
	$opts->{$name} = $p;
    }
    else {
	die("?".__x("Ongeldige periode-aanduiding: {per}",
		    per => $value)."\n");
    }
}

sub date_arg {
    my ($opts, $name, $value) = @_;
    if ( my $p = parse_date($value, substr($dbh->adm("begin"),0,4)) ) {
	$opts->{$name} = $p;
    }
    else {
	die("?".__x("Ongeldige datum: {per}",
		    per => $value)."\n");
    }
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
