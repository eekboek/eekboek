#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.19 2005/09/20 16:11:11 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 20 17:49:36 2005
# Update Count    : 349
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

use EB;
use EB::DB;
use EB::Finance;
use EB::Tools::Opening;

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
      die("?".__x("Onbekend of verkeerd dagboek: {dbk} [{type}]",
		  dbk => $dagboek, type => $dagboek_type)."\n");
    }

    my $opts = { dagboek      => $dagboek,
		 dagboek_type => $dagboek_type,
		 journal      => $self->{journal},
		 totaal	      => undef,
		 verbose      => $self->{verbose},
	       };

    my $args = \@args;
    parse_args($args,
	       [ 'boekstuk|nr=s',
		 'journal!',
		 'totaal=s',
		 'verbose!',
		 'confirm!',
		 ( $dagboek_type == DBKTYPE_BANK
		   || $dagboek_type == DBKTYPE_KAS ) ? ( 'saldo=s' ) : (),
		 'trace!',
	       ], $opts);

    $bsk = $action->perform($args, $opts);
    $bsk ? $bsk =~ /^\d+/ ? __x("Boekstuk: {bsk}", bsk => $bsk) : $bsk	: "";
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
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
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
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
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

sub do_database { __x("Database: {db}", db => $ENV{EB_DB_NAME}) }
sub intro {
    my $self = $_[0];
    goto &do_database if $self->{interactive};
    undef;
}
sub outro { undef }
sub postcmd { shift; $dbh->rollback; shift }

sub do_btwaangifte {
    my $self = shift;
    use EB::BTWAangifte;
    EB::BTWAangifte->new->perform({periode => shift});
    undef;
}

sub help_btwaangifte {
    <<EOS;
Print de BTW aangifte.

  btwaangifte [ periode ]

Aangifteperiode kan zijn:

  j            het gehele jaar
  k1 k2 k3 k4  1e/2e/3e/4e kwartaal (ook: q1, ...)
  1 2 3 .. 12  maand
EOS
}

sub do_dump_schema {
    my ($self, @args) = @_;

    my $opts = { sql => 0,
	       };

    parse_args(\@args,
	       [ 'sql!',
	       ], $opts)
      or goto &help_dumpschema;

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
    my $opts = { verbose      => $self->{verbose},
	       };

    parse_args(\@args,
	       [ 'verbose!',
		 'trace!',
	       ], $opts);

    use EB::Booking::Delete;
    @args = ($bsk) if $bsk && !@args;
    return _T("Gaarne een boekstuk") unless @args == 1;
    my $cmd;
    if ( $self->{interactive} ) {
	$cmd = EB::Booking::Decode->decode($bsk, { trail => 1, bsknr => 1, single => 1 });
    }
    my $res = EB::Booking::Delete->new->perform($bsk, $opts);
    if ( $res !~ /^[?!]/ ) {	# no error
	$self->term->addhistory($cmd);
    }
    $res;
}

sub help_verwijder {
    <<EOS;
Verwijdert een boekstuk. Het boekstuk mag niet in gebruik zijn.

  verwijder <boekstuk>
EOS
}

sub do_toon {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { bverbose => !$self->{verbose},
		 bsknr    => 1,
	       };

    parse_args(\@args,
	       [ 'btw!',
		 'bsknr!',
		 'debcrd!',
		 'verbose!',
		 'trace!',
	       ], $opts);

    $opts->{trail} = !$opts->{verbose};

    use EB::Booking::Decode;
    @args = ($bsk) if $bsk && !@args;
    return _T("Gaarne een boekstuk") unless @args == 1;
    my ($id, $dbs, $err) = $dbh->bskid(shift(@args));
    unless ( defined($id) ) {
	warn("?".$err."\n");
	return;
    }
    my $res = EB::Booking::Decode->decode($id, $opts);
    if ( $res !~ /^[?!]/ && $opts->{trail} ) {	# no error
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

  --verbose      toon in uitgebreide vorm
  --btw       vermeld altijd BTW codes
  --debcrd    vermeld altijd Debet/Credit codes
  --bsknr     vermeld altijd het boekstuknummer
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
