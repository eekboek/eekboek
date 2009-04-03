#! perl

package main;

our $cfg;
our $dbh;

package EB::Shell;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.110 $ =~ /(\d+)/g;

use EB;

my $bky;			# current boekjaar (if set)

use base qw(EB::Shell::DeLuxe);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $opts = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };

    if ( $opts->{command} && $ARGV[0] eq "import" ) {
	$dbh->connectdb(1);
    }
    else {
	_plug_cmds();
    }

    # User defined stuff.
    my $pkg = $cfg->val(qw(shell userdefs), undef);
    if ( $pkg ) {
	$pkg =~ s/::/\//g;
	$pkg .= ".pm";
	eval { require $pkg };
	die($@) if $@;
    }
    else {
	eval { require EB::Shell::Userdefs };
	die($@) if $@ && $@ !~ /can't locate eb.shell.userdefs\.pm in \@inc/i;
    }

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
    my $t = $cfg->val(qw(database name));
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
sub postcmd {
    shift;
    if ( $dbh->in_transaction ) {
	warn("%"._T("Openstaande transactie teruggedraaid")."\n");
	$dbh->rollback;
    }
    shift
}

sub bky_msg {
    my $sth = $dbh->sql_exec("SELECT bky_code".
			     " FROM Boekjaren".
			     " WHERE bky_end < ?".
			     " AND NOT bky_opened IS NULL".
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
	my $rr = $sth->fetchrow_arrayref;
	return () unless $rr;
	my ($w, $d) = @$rr;
	$rr = $sth->fetchrow_arrayref;
	return ($w) unless $rr;
	print STDERR ("\n");
	printf STDERR ("%9d  %s\n", $w, $d);
	while ( $rr ) {
	    printf STDERR ("%9d  %s\n", @$rr);
	    $rr = $sth->fetchrow_arrayref;
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
	my $rr = $sth->fetchrow_arrayref;
	return () unless $rr;

	my ($w, $d) = @$rr;
	$rr = $sth->fetchrow_arrayref;

	if ( !$rr && $word ne "" ) {
	    return ($w);
	}
	print STDERR ("\n");
	printf STDERR ("  %s  %s\n", $w, $d);
	while ( $rr  ) {
	    printf STDERR ("  %s  %s\n", @$rr);
	    $rr = $sth->fetchrow_arrayref;
	}
	print STDERR ("$line");
	return ();
    }
    #warn "\n[$pre][", substr($line, $pos), "]\n";
    return ();
}

sub parseline {
    my ($self, $line) = @_;
    $line =~ s/\\\s*$//;
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

# Plug in some commands dynamically.
sub _plug_cmds {
    my $does_btw = $dbh->does_btw;
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
	    $dbk_pat .= lc($dbk_desc)."|";
	}
	elsif ( $dbk_type == DBKTYPE_VERKOOP ) {
	    $dbk_i_pat .= lc($dbk_desc)."|";
	    $dbk_pat .= lc($dbk_desc)."|";
	}
	else {
	    $dbk_bkm_pat .= lc($dbk_desc)."|";
	    $dbk_pat .= lc($dbk_desc)."|";
	}
    }

    # Opening (adm_...) commands.
    require EB::Tools::Opening;
    foreach my $adm ( @{EB::Tools::Opening->commands} ) {
	my $cmd = $adm;
	$cmd =~ s/^set_//;
	next if $cmd =~ /^btw/ && !$does_btw;
	no strict 'refs';
	*{"do_adm_$cmd"} = sub {
	    (shift->{o} ||= EB::Tools::Opening->new)->$adm(@_);
	};
	my $help = "help_$cmd";
	*{"help_adm_$cmd"} = sub {
	    my $self = shift;
	    ($self->{o} ||= EB::Tools::Opening->new)->can($help)
	      ? $self->{o}->$help() : $self->{o}->shellhelp($cmd);
	};
    }

    # BTW aangifte.
    if ( $does_btw ) {
	no strict 'refs';
	*{"do_btwaangifte"}   = \&_do_btwaangifte;
	*{"help_btwaangifte"} = \&_help_btwaangifte;
    }

    foreach ($dbk_pat, $dbk_i_pat, $dbk_v_pat, $dbk_bkm_pat) {
	chop if $_;
    }
}

sub _help {
    my ($self, $dbk, $dbk_id, $dbk_desc, $dbk_type) = @_;
    my $cmd = "$dbk"."[:nr]";
    my $text = "Toevoegen boekstuk in dagboek $dbk_desc (type " .
      DBKTYPES->[$dbk_type] . ").\n\n";

    if ( $dbk_type == DBKTYPE_INKOOP ) {
	$text .= <<EOS;
  $cmd [ <datum> ] <boekstukomschrijving> <crediteur>

gevolgd door een of meer:

  <boekstukregelomschrijving> <bedrag> <rekening>

Controle van het totale boekstukbedrag kan met de optie --totaal=<bedrag>.
De laatste <rekening> mag worden weggelaten.
EOS
    }
    elsif ( $dbk_type == DBKTYPE_VERKOOP ) {
	$text .= <<EOS;
  $cmd [ <datum> ] <boekstukomschrijving> <debiteur>

gevolgd door een of meer

  <boekstukregelomschrijving> <bedrag> <rekening>

Controle van het totale boekstukbedrag kan met de optie --totaal=<bedrag>.
De laatste <rekening> mag worden weggelaten.
EOS
    }
    elsif ( $dbk_type == DBKTYPE_BANK || $dbk_type == DBKTYPE_KAS 
	    || $dbk_type == DBKTYPE_MEMORIAAL
	  ) {
	$text .= <<EOS;
  $cmd [ <datum> ] <boekstukomschrijving>

gevolgd door een of meer:

  crd [ <datum> ] <code> <bedrag>                       (betaling van crediteur)
  deb [ <datum> ] <code> <bedrag>                       (betaling van debiteur)
  std [ <datum> ] <omschrijving> <bedrag> <rekening>    (vrije boeking)

Controle van het eindsaldo kan met de optie --saldo=<bedrag>.
Controle van het totale boekstukbedrag kan met de optie --totaal=<bedrag>.
Voor deelbetalingen of betalingen met afwijkend bedrag kan in plaats van de
<code> het boekstuknummer worden opgegeven.
EOS
    }
    $text;
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
    my ($self, @args) = @_;
    my $opts = { quiet => 0 };
    return unless
    parse_args(\@args,
	       [ 'quiet!' ],
	       $opts);
    return unless argcnt(@args, 0, 1);
    my $state = shift(@args);
    $self->{trace} = _state($self->{trace}, $state);

    if ( $dbh ) {
	$dbh->trace($self->{trace});
    }
    return "" if $opts->{quiet};
    __x("SQL Trace: {state}", state => uc($self->{trace} ? _T("aan") : _T("uit")));
}

sub do_journal {
    my ($self, @args) = @_;
    my $opts = { quiet => 0 };
    return unless
    parse_args(\@args,
	       [ 'quiet!' ],
	       $opts);
    return unless argcnt(@args, 0, 1);
    my $state = shift(@args);
    $self->{journal} = _state($self->{journal}, $state);
    return "" if $opts->{quiet};
    __x("Journal: {state}", state => uc($self->{journal} ? _T("aan") : _T("uit")));
}

sub do_confirm {
    my ($self, @args) = @_;
    my $opts = { quiet => 0 };
    return unless
    parse_args(\@args,
	       [ 'quiet!' ],
	       $opts);
    return unless argcnt(@args, 0, 1);
    my $state = shift(@args);
    $self->{confirm} = _state($self->{confirm}, $state);
    return "" if $opts->{quiet};
    __x("Bevestiging: {state}", state => uc($self->{confirm} ? _T("aan") : _T("uit")));
}

sub do_database {
    my ($self, @args) = @_;
    return unless argcnt(scalar(@args), 0);
    __x("Database: {db}", db => $cfg->val(qw(database name)));
}

sub help_database {
    <<EOD;
Toont de naam van de huidige database.

  database
EOD
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
		 ref	      => undef,
		 verbose      => $self->{verbose},
		 confirm      => $self->{confirm},
	       };

    my $args = \@args;
    return unless
    parse_args($args,
	       [ 'boekstuk|nr=s',
		 'boekjaar=s',
		 'journal!',
		 'totaal=s',
		 'ref=s',
		 'confirm!',
		 ( $dagboek_type == DBKTYPE_BANK
		   || $dagboek_type == DBKTYPE_KAS ) ? ( 'saldo=s', 'beginsaldo=s' ) : (),
	       ], $opts);

    $opts->{boekjaar} = $opts->{d_boekjaar} unless defined $opts->{boekjaar};
    $bsk = $action->perform($args, $opts);
    $bsk ? $bsk =~ /^\w+:\d+/ ? __x("Geboekt: {bsk}", bsk => $bsk) : $bsk : "";
}

################ Reports ################

sub do_journaal {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { detail       => 1,
		 d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Journal;
    require EB::Report::GenBase;

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
Overzicht journaalposten.

  journaal all                Alle posten
  journaal <id>               Alleen boekstuknummer met dit id
  journaal <dagboek>          Alle journaalposten van dit dagboek
  journaal <dagboek>:<n>      Boekstuk <n> van dit dagboek
  journaal                    Journaalposten van de laatste boeking

Opties

  --[no]detail                Mate van detail, standaard is met details
  --totaal                    Alleen het totaal (detail = 0)
  --periode=XXX               Alleen over deze periode

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_balans {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Balres;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'opening',
		 'boekjaar=s',
		 'per=s' => sub { date_arg($opts, @_) },
		 EB::Report::GenBase->backend_options(EB::Report::Balres::, $opts),
	       ], $opts);
    return unless argcnt(@args, 0);

    if ( $opts->{opening} && $opts->{per} ) {
	warn("?"._T("Openingsbalans kent geen einddatum")."\n");
	return;
    }

    EB::Report::Balres->new->balans($opts);
    undef;
}

sub help_balans {
    <<EOS;
Toont de balansrekening.

Opties:
  <geen>                      Balans op grootboekrekening
  --verdicht                  Verdicht, gedetailleerd
  --detail=<n>                Verdicht, mate van detail <n> = 0, 1 of 2
  --per=<datum>               Selecteer einddatum
  --boekjaar=<code>           Selecteer boekjaar
  --opening                   Toon openingsbalans

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_result {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Balres;
    require EB::Report::GenBase;

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
Toont de resultatenrekening.

Opties:
  <geen>                      Overzicth op grootboekrekening
  --verdicht                  Verdicht, gedetailleerd
  --detail=<n>                Verdicht, mate van detail <n> = 0,1,2
  --periode=<periode>         Selecteer periode
  --boekjaar=<code>           Selecteer boekjaar

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_proefensaldibalans {
    my ($self, @args) = @_;

    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Proof;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'verdicht',
		 'boekjaar=s',
		 'per=s' => sub { date_arg($opts, @_) },
		 EB::Report::GenBase->backend_options(EB::Report::Proof::, $opts),
	       ], $opts);
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
    EB::Report::Proof->new->proefensaldibalans($opts);
    undef;
}

sub help_proefensaldibalans {
    <<EOS;
Toont de Proef- en Saldibalans.

Opties:
  <geen>                      Proef- en Saldibalans op grootboekrekening
  --verdicht                  Verdicht, gedetailleerd (zelfde als --detail=2)
  --detail=<n>                Verdicht, mate van detail <n> = 0,1,2
  --per=<datum>               Selecteer einddatum
  --boekjaar=<code>           Selecteer boekjaar

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_grootboek {
    my ($self, @args) = @_;

    my $opts = { detail       => 2,
		 d_boekjaar   => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Grootboek;
    require EB::Report::GenBase;

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
Toont het Grootboek, of een selectie daaruit.

  grootboek [ <rek> ... ]

Opties:

  --detail=<n>                Mate van detail, <n>=0,1,2 (standaard is 2)
  --periode=<periode>         Alleen over deze periode

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
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
Toont een lijstje van beschikbare dagboeken.

  dagboeken
EOS
}

# do_btwaangifte and help_btwaangifte are dynamically plugged in (or not).
sub _do_btwaangifte {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar   => $bky || $dbh->adm("bky"),
		 close	      => 0,
	       };

    require EB::Report::BTWAangifte;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ "boekjaar=s",
		 'periode=s'  => sub { periode_arg($opts, @_) },
		 "definitief" => sub { $opts->{close} = 1 },
		 EB::Report::GenBase->backend_options(EB::Report::BTWAangifte::, $opts),
		 "noreport",
		 "noround",
	       ], $opts)
      or goto &_help_btwaangifte;

    if ( @args && lc($args[-1]) eq "definitief" ) {
	$opts->{close} = 1;
	pop(@args);
    }
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return
      if @args > ($opts->{periode} ? 0 : 1);
    $opts->{compat_periode} = $args[0] if @args;
    EB::Report::BTWAangifte->new($opts)->perform($opts);
    undef;
}

sub _help_btwaangifte {
    <<EOS;
Toont de BTW aangifte.

  btwaangifte [ <opties> ] [ <aangifteperiode> ]

Aangifteperiode kan zijn:

  j jaar                      Het gehele jaar
  k1 k2 k3 k4                 1e/2e/3e/4e kwartaal (ook: q1, ...)
  1 2 3 ...                   Maand (op nummer)
  jan feb ...                 Maand (korte naam)
  januari ...                 Maand (lange naam)

Standaard is de eerstvolgende periode waarover nog geen aangifte is
gedaan.

Opties:

  --definitief                De BTW periode wordt afgesloten. Er zijn geen
                              boekingen in deze periode meer mogelijk.
  --periode=<periode>         Selecteer aangifteperiode. Dit kan niet samen
                              met --boekjaar, en evenmin met de bovenvermelde
                              methode van periode-specificatie.
  --boekjaar=<code>           Selecteer boekjaar
  --noreport                  Geen rapportage. Dit is enkel zinvol samen
                              met --definitief om de afgesloten BTW periode
                              aan te passen.
  --noround		      Alle bedragen zonder af te ronden.

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_debiteuren {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Debcrd;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ "boekjaar=s",
		 EB::Report::GenBase->backend_options(EB::Report::Debcrd::, $opts),
		 'periode=s' => sub { periode_arg($opts, @_) },
		 'openstaand',
	       ], $opts);

    EB::Report::Debcrd->new->debiteuren(\@args, $opts);
}

sub help_debiteuren {
    <<EOS;
Toont een overzicht van boekingen op debiteuren.

  debiteuren [ <opties> ] [ <relatiecodes> ... ]

Opties:

  --periode <periode>         Periode
  --boekjaar=<code>           Selecteer boekjaar
  --openstaand                Alleen met openstaande posten

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_crediteuren {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Debcrd;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ "boekjaar=s",
		 EB::Report::GenBase->backend_options(EB::Report::Debcrd::, $opts),
		 'periode=s' => sub { periode_arg($opts, @_) },
		 'openstaand',
	       ], $opts);

    EB::Report::Debcrd->new->crediteuren(\@args, $opts);
}

sub help_crediteuren {
    <<EOS;
Toont een overzicht van boekingen op crediteuren.

  crediteuren [ <opties> ] [ <relatiecode> ... ]

Opties:

  --periode=<periode>         Periode
  --boekjaar=<code>           Selecteer boekjaar
  --openstaand                Alleen met openstaande posten

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub do_openstaand {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky || $dbh->adm("bky"),
	       };

    require EB::Report::Open;
    require EB::Report::GenBase;

    return unless
    parse_args(\@args,
	       [ "boekjaar=s",
		 EB::Report::GenBase->backend_options(EB::Report::Open::, $opts),
		 'per=s' => sub { date_arg($opts, @_) },
		 'deb|debiteuren',
		 'crd|crediteuren',
	       ], $opts);

    return unless argcnt(@args, 0, 1);
    EB::Report::Open->new->perform($opts, \@args);
}

sub help_openstaand {
    <<EOS;
Toont een overzicht van openstaande posten.

  openstaand [ <opties> ] [ <relatie> ]

Opties:

  --per=<datum>               Einddatum
  --boekjaar=<code>           Selecteer boekjaar
  --deb --debiteuren          Alleen debiteuren
  --crd --crediteuren         Alleen crediteuren

Zie verder "help rapporten" voor algemene informatie over aan te maken
rapporten.
EOS
}

sub help_rapporten {
    <<EOS;
Alle rapport-producerende opdrachten kennen de volgende opties:

  --per=<datum>               De einddatum voor de rapportage.
                              (Niet voor elke opdracht relevant.)
                              Zie "help periodes" voor details.
  --periode=<periode>         De periode waarover de rapportage moet
                              plaatsvinden. (Niet voor elke opdracht relevant.)
                              Zie "help periodes" voor details.
  --output=<bestand>          Produceer het rapport in dit bestand
                              Uitvoertype is afhankelijk van bestandsextensie,
                              bv. xx.html levert HTML, xx.txt een tekstbestand,
                              xx.csv een CSV, etc.
  --gen-<type>                Forceer uitvoertype (html, csv, text, ...)
                              Afhankelijk van de beschikbare uitvoertypes zijn
                              ook de kortere opties --html, --csv en --text
                              mogelijk.
		              (Let op: --gen-XXX, niet --gen=XXX)
  --page=<size>               Paginagrootte voor tekstrapporten.
EOS
}

sub help_periodes {
    <<EOS;
De volgende periode-aanduidingen zijn mogelijk. Indien het jaartal ontbreekt,
wordt het huidige boekjaar verondersteld.

  2005-04-01 - 2005-07-31
  01-04-2005 - 31-07-2005
  01-04 - 31-07-2005
  01-04 - 31-07
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
		 $dbh->does_btw ? 'btw=s' : (),
	       ], $opts)
      or goto &help_relatie;

    warn("?"._T("Ongeldig aantal argumenten voor deze opdracht")."\n"), return if @args % 3;

    require EB::Relation;

    while ( @args ) {
	my @a = splice(@args, 0, 3);
	my $res = EB::Relation->new->add(@a, $opts);
	warn("$res\n") if $res;
    }
}

sub help_relatie {
    my $ret = <<EOS;
Aanmaken een of meer nieuwe relaties.

  relatie [ <opties> ] { <code> <omschrijving> <rekening> } ...

Opties:

  --dagboek=<dagboek>         Selecteer dagboek voor deze relatie
EOS

    $ret .= <<EOS if $dbh->does_btw;
  --btw=<type>                BTW type: normaal, verlegd, intra, extra

*** BTW type 'verlegd' wordt nog niet ondersteund ***
*** BTW type 'intra' wordt nog niet geheel ondersteund ***
EOS
    $ret;
}

################ Im/export ################

sub do_export {
    my ($self, @args) = @_;

    my $opts = { single   => 0,
		 explicit => 0,
		 totals   => 1,
	       };

    return unless
    parse_args(\@args,
	       [ 'dir=s',
		 'file|output=s',
		 'boekjaar=s',
		 'xaf=s',
		 'single',
		 'explicit',
		 'totals!',
	       ], $opts)
      or goto &help_export;

    my $t = 0;
    $t++ if defined($opts->{dir});
    $t++ if defined($opts->{file});
    $t++ if defined($opts->{xaf});
    if ( $t > 1 ) {
	warn("?"._T("Opties --dir, --file en --xaf sluiten elkaar uit")."\n");
	return;
    }
    if ( $t != 1 ) {
	warn("?"._T("Specifieer --dir, --file of --xaf")."\n");
	return;
    }

    return unless argcnt(@args, 0);
    check_open(1);

    if ( $opts->{xaf} ) {
	if ( findlib "Export/XAF.pm" ) {
	    require EB::Export::XAF;
	    # XAF bevat altijd maar één boekjaar.
	    $opts->{boekjaar} ||= $bky;
	    EB::Export::XAF->export($opts);
	}
	else {
	    warn("?"._T("Export naar XML Auditfile Financieel is niet beschikbaar")."\n");
	}
    }
    else {
	if ( $opts->{boekjaar} ) {
	    warn("?"._T("Optie --boekjaar wordt niet ondersteunt door deze export")."\n");
	return;
	}
	require EB::Export;
	EB::Export->export($opts);
    }

    return;
}

sub help_export {
    <<EOS;
Exporteert de complete administratie.

  export [ <opties> ]

Opties:

  --file=<bestand>          Selecteer uitvoerbestand
  --dir=<directory>         Selecteer uitvoerdirectory
  --xaf=<bestand>           Export XML Auditfile Financieel
  --boekjaar=<code>         Selecteer boekjaar (alleen met --xaf)

Er moet een --file, --dir of een --xaf optie worden opgegeven.
De XAF export exporteert altijd één enkel boekjaar. Voor de andere
exports wordt altijd de gehele administratie geëxporteerd.
Eventueel bestaande files worden overschreven.
EOS
}

sub do_import {
    my ($self, @args) = @_;
    my $opts = { clean => 1,
	       };

    return unless
    parse_args(\@args,
	       [ 'dir=s',
		 'file=s',
		 'clean!',
	       ], $opts);

    if ( defined($opts->{dir}) && defined($opts->{file}) ) {
	warn("?"._T("Opties --dir en --file sluiten elkaar uit")."\n");
	return;
    }
    if ( !defined($opts->{dir}) && !defined($opts->{file}) ) {
	warn("?"._T("Specifieer --dir of --file")."\n");
	return;
    }

    return unless argcnt(scalar(@args), 0);

    if ( $opts->{clean} && !$dbh->feature("import") ) {
	warn("?".__x("Database type {drv} ondersteunt niet het import commando. Gebruik de --import command line optie.",
		     drv => $dbh->driverdb)."\n");
	return;
    }

    require EB::Import;
    EB::Import->do_import($self, $opts);

    return;
}

sub help_import {
    <<EOS;
Importeert een complete, geëxporteerde administratie.

  import [ <opties> ]

Opties:

  --input=<bestand>           Selecteer exportbestand
  --dir=<directory>           Selecteer exportdirectory

Er moet of een --input of een --dir optie worden opgegeven.

LET OP: IMPORT VERVANGT DE COMPLETE ADMINISTRATIE!
EOS
}

sub do_include {
    my ($self, @args) = @_;
    my $opts = { optional => 0,
	       };

    return unless
    parse_args(\@args,
	       [ 'optional|optioneel',
	       ], $opts);
    return unless argcnt(scalar(@args), 1);
    my $file = shift(@args);
    if ( open(my $fd, '<', $file) ) {
	$self->attach_file($fd);
    }
    elsif ( !$opts->{optional} ) {
	die("$file: $!\n");
    }
    ""
}

sub help_include {
    <<EOS;
Leest opdrachten uit een bestand.

  include [ <opties> ] <bestand>

Opties:

  --optioneel                 Het bestand mag ontbreken. De opdracht
                              wordt dan verder genegeerd.
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

    <<EOS;
Deze opdracht is vervallen. Gebruik in plaats daarvan "export".
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

    require EB::Booking::Delete;
    require EB::Booking::Decode;
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
	$cmd = EB::Booking::Decode->decode($id, { boekjaar => $opts->{boekjaar}, trail => 1, bsknr => 1, single => 1 });
    }
    my $res = EB::Booking::Delete->new->perform($id, $opts);
    if ( $res && $self->{interactive} && $res !~ /^[?!]/ ) {	# no error
	$self->term->addhistory($cmd);
    }
    $res;
}

sub help_verwijder {
    <<EOS;
Verwijdert een boekstuk. Het boekstuk mag niet in gebruik zijn.

  verwijder [ <opties> ] <boekstuk>

Opties:

  --boekjaar=<code>           Selekteer boekjaar

Het verwijderde boekstuk wordt in de commando-historie geplaatst.
Met een pijltje-omhoog kan dit worden teruggehaald en na eventuele
wijziging opnieuw ingevoerd.
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
		 'bky!',
		 'totaal!',
		 'boekjaar=s',
		 'verbose!',
		 'trace!',
	       ], $opts);

    $opts->{trail} = !$opts->{verbose};
    $opts->{boekjaar} = $opts->{d_boekjaar} unless defined $opts->{boekjaar};

    require EB::Booking::Decode;
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
Toont een boekstuk in tekst- of commando-vorm.

  toon [ <opties> ] <boekstuk>

Opties:

  --boekjaar=<code>           Selekteer boekjaar
  --verbose                   Toon in uitgebreide (tekst) vorm
  --btw                       Vermeld altijd BTW codes
  --bsknr                     Vermeld altijd het boekstuknummer (default)

Het getoonde boekstuk wordt in de commando-historie geplaatst.
Met een pijltje-omhoog kan dit worden teruggehaald en na eventuele
wijziging opnieuw ingevoerd.
EOS
}

sub do_jaareinde {
    my ($self, @args) = @_;
    my $opts = { d_boekjaar => $bky,
	       };

    return unless
    parse_args(\@args,
	       [ 'boekjaar=s',
		 'definitief',
		 'verwijder',
		 'eb=s',
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
winst of het verlies wordt verrekend met de daartoe aangewezen
balansrekening.

Deze opdracht genereert twee rapporten: een journaal van de
afboekingen en een overzicht van eventuele openstaande posten. Indien
gewenst kan een bestand worden aangemaakt met openingsopdrachten voor
het volgende boekjaar.

  jaareinde [ <opties> ]

Opties:

  --boekjaar=<code>           Sluit het opgegeven boekjaar af.
  --definitief                Sluit het boekjaar definitief af. Er zijn
                              dan geen boekingen meer mogelijk.
  --verwijder                 Verwijder een niet-definitieve jaarafsluiting.
  --eb=<bestand>              Schrijf openingsopdrachten in dit bestand.
EOS
}

sub do_sql {
    my ($self, @args) = @_;
    $dbh->isql(@args);
    undef;
}

sub help_sql {
    <<EOD;
Voer een SQL opdracht uit via de database driver. Met het gebruik
hiervan vervalt alle garantie op correcte resultaten.

  sql [ <opdracht> ]
EOD
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
    if ( $open && !$dbh->adm_open ) {
	die("?"._T("De administratie is nog niet geopend")."\n");
    }
    elsif ( !$open && $dbh->adm_open ) {
	die("?"._T("De administratie is reeds geopend")."\n");
    }
    1;
}

sub check_busy {
    my ($self, $busy) = @_;
    $busy = 1 unless defined($busy);
    if ( $busy && !$dbh->adm_busy ) {
	die("?"._T("De administratie is nog niet in gebruik")."\n");
    }
    elsif ( !$busy && $dbh->adm_busy ) {
	die("?"._T("De administratie is reeds in gebruik")."\n");
    }
    1;
}

1;
