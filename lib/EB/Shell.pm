#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.78 2006/06/20 19:48:08 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Jun 20 20:45:36 2006
# Update Count    : 811
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

use strict;

# Package or program libraries, if appropriate.
# $LIBDIR = $ENV{'LIBDIR'} || '/usr/local/lib/sample';
# use lib qw($LIBDIR);
# require 'common.pl';

# Package name.
my $my_package; BEGIN { $my_package = 'EekBoek' }

# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ Configuration ################

our $cfg;
our $dbh;

sub shell {

# This will set up the config at 'use' time.
use EB::Config $my_package;

if ( @ARGV && ( $ARGV[0] eq '-P' || $ARGV[0] =~ /^--?printcfg$/ ) ) {
    shift(@ARGV);
    printconf();
    exit;
}

################ Command line parameters ################

use Getopt::Long 2.13;

# Command line options.
my $interactive = -t;
my $command;
my $echo;
my $dataset;
my $createdb;			# create database
my $schema;			# initialise w/ schema
my $confirm = 0;
my $journal = 0;
my $verbose = 0;		# verbose processing
my $bky;

# Development options (not shown with -help).
my $debug = 0;			# debugging
my $trace = 0;			# trace (show process)
my $test = 0;			# test mode.

# Process command line options.
app_options();

# Post-processing.
$trace |= ($debug || $test);

################ Presets ################

my $TMPDIR = $ENV{TMPDIR} || $ENV{TEMP} || '/usr/tmp';

################ The Process ################

use EB;
#use base qw(EB::Shell);

my $app = $my_package;
my $userdir = glob("~/.".lc($app));
mkdir($userdir) unless -d $userdir;

$echo = "eb> " if $echo;

$dataset ||= $cfg->val(qw(database name), undef);

unless ( $dataset ) {
    die("?"._T("Geen dataset opgegeven.".
	       " Specificeer een dataset in de configuratiefile,".
	       " of geef een dataset".
	       " naam mee op de command line met \"--dataset=...\".").
	"\n");
}

$cfg->newval(qw(database name), $dataset);

use EB::DB;
our $dbh = EB::DB->new(trace => $trace);

if ( $createdb ) {
    $dbh->createdb($dataset);
    warn("%".__x("Lege dataset {db} is aangemaakt", db => $dataset)."\n");
}

if ( $schema ) {
    require EB::Tools::Schema;
    $dbh->connectdb(1);
    EB::Tools::Schema->create($schema);
}

exit(0) if $command && !@ARGV;

my $shell = EB::Shell->new
  ({ HISTFILE	  => $userdir."/history",
     command	  => $command,
     interactive  => $interactive,
     verbose	  => $verbose,
     trace	  => $trace,
     journal	  => $journal,
     echo	  => $echo,
     prompt	  => lc($app),
     boekjaar	  => $bky,
   });

$| = 1;

$shell->run;

################ Subroutines ################

sub printconf {
    return unless @ARGV > 0;
    my $sec = "general";
    if ( !GetOptions(
		     'section=s' => \$sec,
		     '<>' => sub {
			 my $conf = shift;
			 my $sec = $sec;
			 ($sec, $conf) = ($1, $2) if $conf =~ /^(.+?):(.+)/;
			 my $val = $cfg->val($sec, $conf, undef);
			 print STDOUT ($val) if defined $val;
			 print STDOUT ("\n");
		     }
		    ) )
    {
	app_ident();
	print STDERR __x(<<EndOfUsage, prog => $0);
Gebruik: {prog} { --printcfg | -P } { [ --section=secname ] var ... } ...

    Print de waarde van configuratie-variabelen.
    Met --section=secname worden de eropvolgende variabelen
    gezocht in sectie [secname].
    Ook: secname:variabele.
EndOfUsage
    }
}

################ Subroutines ################

sub app_options {
    my $help = 0;		# handled locally
    my $ident = 0;		# handled locally

    # Process options, if any.
    # Make sure defaults are set before returning!
    return unless @ARGV > 0;

    Getopt::Long::Configure(qw(no_ignore_case));

    if ( !GetOptions(
		     'command|c' => sub {
			 $command = 1;
			 die("!FINISH\n");
		     },
		     'import' => sub {
			 $command = 1;
			 $createdb = 1;
			 unshift(@ARGV, "import", "--noclean");
			 die("!FINISH\n");
		     },
		     'export' => sub {
			 $command = 1;
			 unshift(@ARGV, "export");
			 die("!FINISH\n");
		     },
		     'createdb' => \$createdb,
		     'define|D=s%' => sub {
			 my ($opt, $key, $arg) = @_;
			 if ( $key =~ /^(.+?)::?([^:]+)$/ ) {
			     $cfg->newval($1, $2, $arg);
			 }
			 else {
			     die(__x("Ongeldige aanduiding voor config setting: {arg}",
				    arg => $key)."\n");
			 }
		     },
		     'schema=s' => \$schema,
		     'echo|e!'	=> \$echo,
		     'ident'	=> \$ident,
		     'journaal|journal'	=> \$journal,
		     'boekjaar=s'	=> \$bky,
		     'verbose'	=> \$verbose,
		     'db|dataset=s' => \$dataset,
		     'trace'	=> \$trace,
		     'help|?'	=> \$help,
		     'debug'	=> \$debug,
		    ) or $help )
    {
	app_usage(2);
    }
    app_usage(2) if @ARGV && !$command;
    app_ident() if $ident;
}

sub app_ident {
    print STDERR (__x("Dit is {pkg} [{name} {version}]",
		      pkg     => $my_package,
		      name    => $my_name,
		      version => $my_version) . "\n");
}

sub app_usage {
    my ($exit) = @_;
    app_ident();
    print STDERR __x(<<EndOfUsage, prog => $0);
Gebruik: {prog} [options] [file ...]

    --command  -c       voer de rest van de opdrachtregel uit als command
    --echo  -e          toon ingelezen opdrachten
    --journaal          toon de journaalregels na elke opdracht
    --dataset=DB        specificeer database
    --db=DB             specificeer database
    --boekjaar=XXX	specificeer boekjaar
    --createdb		maak nieuwe database aan
    --schema=XXX        initialisser database met schema
    --import --dir=XXX  importeer een nieuwe administratie
    --export --dir=XXX  exporteer een administratie
    --define=XXX -D     definieer configuratiesetting
    --help		deze hulpboodschap
    --ident		toon identificatie
    --verbose		geef meer uitgebreide information
EndOfUsage
    exit $exit if defined $exit && $exit != 0;
}

}

package EB::Shell;

use strict;

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

# Standard options for report generating backends.
my @outopts;
INIT { @outopts = qw(html csv text output=s page=i) }

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
	}
	elsif ( $dbk_type == DBKTYPE_VERKOOP ) {
	    $dbk_i_pat .= lc($dbk_desc)."|";
	}
	else {
	    $dbk_bkm_pat .= lc($dbk_desc)."|";
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

    $dbk_pat = $dbk_i_pat.$dbk_v_pat.$dbk_bkm_pat;
    chop foreach ($dbk_pat, $dbk_i_pat, $dbk_v_pat, $dbk_bkm_pat);
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
    my ($self, $state) = @_;
    return unless argcnt(scalar(@_), 1, 2);
    $self->{trace} = _state($self->{trace}, $state);

    if ( $dbh ) {
	$dbh->trace($self->{trace});
    }
    __x("SQL Trace: {state}", state => uc($self->{trace} ? _T("aan") : _T("uit")));
}

sub do_journal {
    my ($self, $state) = @_;
    return unless argcnt(scalar(@_), 1, 2);
    $self->{journal} = _state($self->{journal}, $state);
    __x("Journal: {state}", state => uc($self->{journal} ? _T("aan") : _T("uit")));
}

sub do_confirm {
    my ($self, $state) = @_;
    return unless argcnt(scalar(@_), 1, 2);
    $self->{confirm} = _state($self->{confirm}, $state);
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
	       ], $opts)
      or goto &_help_btwaangifte;

    if ( lc($args[-1]) eq "definitief" ) {
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
	       ], $opts);

    return unless argcnt(@args, 0);
    EB::Report::Open->new->perform($opts);
}

sub help_openstaand {
    <<EOS;
Toont een overzicht van openstaande posten.

  openstaand [ <opties> ]

Opties:

  --per=<datum>               Einddatum
  --boekjaar=<code>           Selecteer boekjaar

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
		 'single',
		 'explicit',
		 'totals!',
	       ], $opts)
      or goto &help_export;

    if ( defined($opts->{dir}) && defined($opts->{file}) ) {
	warn("?"._T("Opties --dir en --file sluiten elkaar uit")."\n");
	return;
    }
    if ( !defined($opts->{dir}) && !defined($opts->{file}) ) {
	warn("?"._T("Specifieer --dir of --file")."\n");
	return;
    }

    return unless argcnt(@args, 0);
    check_open(1);

    require EB::Export;
    EB::Export->export($opts);

    return;
}

sub help_export {
    <<EOS;
Exporteert de complete administratie.

  export [ <opties> ]

Opties:

  --file=<bestand>          Selecteer uitvoerbestand
  --dir=<directory>           Selecteer uitvoerdirectory
  --boekjaar=<code>           Selecteer boekjaar

Er moet of een --file of een --dir optie worden opgegeven.
Zonder --boekjaar selectie wordt de gehele administratie geëxporteerd.
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

    my $opts = { sql => 0,
	       };

    return unless
    parse_args(\@args,
	       [ 'sql!',
	       ], $opts)
      or goto &help_dump_schema;

    require EB::Tools::Schema;

    if ( $opts->{sql} ) {
	return unless argcnt(scalar(@args), 1);
	EB::Tools::Schema->dump_sql(@args);
    }
    else {
	return unless argcnt(scalar(@args), 0);
	EB::Tools::Schema->dump_schema;
    }
    "";
}

sub help_dump_schema {
    <<EOS;
Reproduceert het schema van de huidige database en schrijft deze naar
standaard uitvoer.

  dump_schema                 Reproduceert het schema van de huidige database
                              en schrijft deze naar standaard uitvoer.

  dump_schema --sql <naam>    Creëert losse SQL bestandjes om het genoemde
                              schema aan te kunnen maken.

Zie ook "help export".
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
