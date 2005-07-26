#!/usr/bin/perl

my $RCS_Id = '$Id: Shell.pm,v 1.7 2005/07/26 18:05:25 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Thu Jul  7 15:53:48 2005
# Last Modified By: Johan Vromans
# Last Modified On: Tue Jul 26 19:53:13 2005
# Update Count    : 215
# Status          : Unknown, Use with caution!

################ Common stuff ################

package EB::Shell;

use strict;
use locale;

use base qw(Shell::DeLuxe);

sub new {
    my $class = shift;
    $class = ref($class) || $class;
    my $opts = UNIVERSAL::isa($_[0], 'HASH') ? shift : { @_ };

    use EB::DB;
    $::dbh ||= EB::DB->new(trace => $opts->{trace});

    _plug_cmds();

    $class->SUPER::new($opts);
}

sub prompt {
    shift->{prompt};
}

################ Subroutines ################

use EB::Globals;
use EB::DB;

sub _plug_cmds {
    my $sth = $::dbh->sql_exec("SELECT dbk_id,dbk_desc,dbk_type FROM Dagboeken");
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

    if ( $::dbh ) {
	$::dbh->trace($self->{trace});
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

    my $dagboek_type = $::dbh->lookup($dagboek, qw(Dagboeken dbk_id dbk_type =));
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
    $b = shift(@args) if @args;
    undef $b if $b && $b eq "all";
    EB::Journal::Text->new->journal($b);
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
    my $opts = {};
    $opts->{detail} = $args[0] if @args;
    EB::Report::Balres->new->balans($opts);
    undef;
}

sub help_balans {
    <<EOS;
Print de balansrekening.

Optionele parameter (0, 1, 2) bepaalt te mate van detail.
EOS
}

sub do_result {
    my ($self, @args) = @_;
    require EB::Report::Balres;
    my $opts = {};
    $opts->{detail} = $args[0] if @args;
    EB::Report::Balres->new->result($opts);
    undef;
}

sub help_result {
    <<EOS;
Print de resultatenrekening.

Optionele parameter (0, 1, 2) bepaalt te mate van detail.
EOS
}

sub do_dagboeken {
    my ($self, @args) = @_;
    my $rr;
    my $sth = $::dbh->exec_sql("SELECT dbk_id, dbk_desc, dbk_type, dbk_acc_id".
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
sub postcmd { shift; $::dbh->rollback; shift }

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

1;
