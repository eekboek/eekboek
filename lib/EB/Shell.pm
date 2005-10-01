#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.27 2005/10/01 09:35:09 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Fri Sep 30 18:42:51 2005
# Update Count    : 482
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

    my $self = $class->SUPER::new($opts);

    if ( $self->{interactive} ) {
	$self->term->Attribs->{completion_function} = sub { $self->eb_complete(@_) };
    }
    $self;
}

sub prompt {
    shift->{prompt};
}

sub default {
    undef;
}

sub intro {
    my $self = $_[0];
    goto &do_database if $self->{interactive};
    undef;
}
sub outro { undef }
sub postcmd { shift; $dbh->rollback; shift }

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

    if ( $i < 0 || $i > $pos-1 ) {
	my @a = grep { /^$word/ } $self->completions;
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
	    $t =~ s/\s+$//;
	    return ($t);
	}
	print STDERR ("\n");
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    printf STDERR ("  %s  %s\n", @$rr);
	}
	print STDERR ("$line");
	return ();
    }
    warn "\n[$pre][", substr($line, $pos), "]\n";
    return ();
}

################ Subroutines ################

use EB;
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
    $line =~ s/;\s*$//;
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
    return unless
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
    my $opts = { detail       => 1,
		 periode      => '',
		 verbose      => $self->{verbose},
		 trace        => $self->{trace},
	       };

    return unless
    parse_args(\@args,
	       [ 'detail!',
		 'totaal' => sub { $opts->{detail} = 0 },
		 'periode=s' => sub { periode_arg($opts, @_) },
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

Opties

  --[no]detail           -- mate van detail, standaard is met details
  --totaal               -- alleen het totaal (detail = 0)
  --periode=XXX          -- alleen over deze periode
EOS
}

sub do_balans {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = { verbose      => $self->{verbose},
	       };

    return unless
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

    return unless
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

    return unless
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
		 periode      => '',
		 verbose      => $self->{verbose},
		 trace        => $self->{trace},
	       };

    return unless
    parse_args(\@args,
	       [ 'detail=i',
		 'periode=s' => sub { periode_arg($opts, @_) },
		 'verbose!',
		 'trace!',
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
Print een lijstje van gebruikte dagboeken.
EOS
}

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

    if ( @args == 4 ) {
	$opts->{btw} = pop(@args);
    }
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args > 3;
    warn("?"._T("Te weinig argumenten voor deze opdracht")."\n"), return if @args < 3;

    use EB::Relation;
    EB::Relation->new->add(@args, $opts);
}

sub help_relatie {
    <<EOS;
Aanmaken nieuwe relatie.

  relatie <code> "Omschrijving" <rekening>

Opties:

  --dagboek=XXX  -- selecteer dagboek voor deze relatie
  --btw=XXX      -- btw-type: normaal, verlegd, intra, extra
EOS
}

sub do_database {
    my ($self, @args) = @_;
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;
    __x("Database: {db}", db => $ENV{EB_DB_NAME})
}

sub do_btwaangifte {
    my ($self, @args) = @_;
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args > 2;
    my $close = 0;
    my $opts = {};
    if ( lc($args[-1]) eq "definitief" ) {
	$close = 1;
	pop(@args);
    }
    $opts->{close} = $close;
    $opts->{periode} = $args[0] if @args;
    use EB::BTWAangifte;
    EB::BTWAangifte->new->perform($opts);
    undef;
}

sub help_btwaangifte {
    <<EOS;
Print de BTW aangifte.

  btwaangifte [ periode ] [ definitief ]

Aangifteperiode kan zijn:

  j            het gehele jaar
  k1 k2 k3 k4  1e/2e/3e/4e kwartaal (ook: q1, ...)
  1 2 3 .. 12  maand

Met de toevoeging "definitief" wordt de BTW periode afgesloten en zijn
geen boekingen meer mogelijk.
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

    return unless
    parse_args(\@args,
	       [ 'verbose!',
		 'trace!',
	       ], $opts);

    use EB::Booking::Delete;
    @args = ($bsk) if $bsk && !@args;
    return _T("Gaarne een boekstuk") unless @args == 1;
    my $cmd;
    my $id = shift(@args);
    if ( $self->{interactive} ) {
	($id, my $dbs, my $err) = $dbh->bskid($id);
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

  verwijder <boekstuk>
EOS
}

sub do_toon {
    my ($self, @args) = @_;
    my $b = $bsk;
    my $opts = { verbose => 0,
		 bsknr    => 1,
	       };

    return unless
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

sub do_openstaand {
    my ($self, @args) = @_;
    warn("?"._T("Te veel argumenten voor deze opdracht")."\n"), return if @args;

    my $opts = { verbose => !$self->{verbose},
		 bsknr    => 1,
	       };

    return unless
    parse_args(\@args,
	       [ 'verbose!',
		 'trace!',
	       ], $opts);

    use EB::Report::Open;
    EB::Report::Open->new->perform($opts);
}

sub help_openstaand {
    <<EOS;
Toont een overzicht van openstaande posten.

  openstaand
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
