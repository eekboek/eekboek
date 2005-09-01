#!/usr/bin/perl -w
my $RCS_Id = '$Id: Schema.pm,v 1.10 2005/09/01 15:41:42 jv Exp $ ';

# Author          : Johan Vromans
# Created On      : Sun Aug 14 18:10:49 2005
# Last Modified By: Johan Vromans
# Last Modified On: Thu Sep  1 17:40:00 2005
# Update Count    : 306
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $config;
our $app;
our $dbh;

package EB::Tools::Schema;

# To be used by the EB::Shell.
#
# Stand-alone use:
#
#   perl EB/Tools/Schema.pm                           -- dumps current schema
#   perl -MEB::Tools::Schema -e 'dump_schema()'       -- same
#   perl -MEB::Tools::Schema -e 'dump_sql("sample")'  -- loads a schema into sql files

use strict;

my $sql = 0;			# load schema into SQL files
my $trace = $ENV{EB_SQL_TRACE} || 0;

# Package name.
my $my_package = 'EekBoek';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ The Process ################

use EB::Globals;
use EB::Finance;
use EB::DB;

################ Subroutines ################

################ Schema Loading ################

my $schema;
my $fh;

sub create {
    shift;			# singleton class method
    my ($name) = @_;
    my $file;
    foreach my $dir ( ".", "schemas", $ENV{EB_LIB}."/EB/schemas" ) {
	foreach my $ext ( "", ".dat" ) {
	    next unless -s "$dir/$name$ext";
	    $file = "$dir/$name$ext";
	    last;
	}
    }

    die("?Onbekend schema: $name\n") unless $file;
    open($fh, "<$file") or die("?Error accessing schema data: $!\n");
    $schema = $name;
    $dbh = EB::DB->new(trace => $trace) unless $sql;
    load_schema();
    "Schema $name geïnitialiseerd";
}

my @hvdi;			# hoofdverdichtingen
my @vdi;			# verdichtingen
my %acc;			# grootboekrekeningen
my $chvdi;			# huidige hoofdverdichting
my $cvdi;			# huidige verdichting
my %std;			# standaardrekeningen
my @dbk;			# dagboeken
my @btw;			# btw tarieven
my %btwmap;			# btw type/incl -> code

my $fail;			# any errors

sub error { warn('?', @_); $fail++; }

sub scan_dagboeken {
    return 0 unless /^\s+(\d+)\s+(.*)/;

    my ($id, $desc) = ($1, $2);
    error("Dubbel: dagboek $id\n") if defined($dbk[$id]);

    my $type;
    my $rek = 0;
    my $extra;
    while ( $desc =~ /^(.+?)\s+:([^\s:]+)\s*$/ ) {
	$desc = $1;
	$extra = $2;
	if ( $extra =~ m/^type=(\S+)$/i ) {
	    my $t = DBKTYPES;
	    for ( my $i = 0; $i < @$t; $i++ ) {
		next unless lc($1) eq lc($t->[$i]);
		$type = $i;
		last;
	    }
	    error("Dagboek $id: onbekend type \"$1\"\n") unless defined($type);
	}
	elsif ( $extra =~ m/^rek(?:ening)?=(\d+)$/i ) {
	    $rek = $1;
	}
	else {
	    error("Dagboek $id: onbekende info \"$extra\"\n");
	}
    }

    error("Dagboek $id: het :type ontbreekt\n") unless defined($type);
    error("Dagboek $id: het :rekening nummer ontbreekt\n")
      if ( $type == DBKTYPE_KAS || $type == DBKTYPE_BANK ) and !$type;
    error("Dagboek $id: rekeningnummer enkel toegestaan voor Kas en Bankboeken $type\n")
      if $rek && !($type == DBKTYPE_KAS || $type == DBKTYPE_BANK);

    $dbk[$id] = [ $id, $desc, $type, $rek||undef ];
}

sub scan_btw {
    return 0 unless /^\s+(\d+)\s+(.*)/;

    my ($id, $desc) = ($1, $2);
    error("Dubbel: BTW tarief $id\n") if defined($btw[$id]);

    my $perc;
    my $groep = 0;
    my $incl = 1;
    my $extra;
    while ( $desc =~ /^(.+?)\s+:([^\s:]+)\s*$/ ) {
	$desc = $1;
	$extra = $2;
	if ( $extra =~ m/^perc(?:entage)?=(\S+)$/i ) {
	    $perc = amount($1);
	    if ( AMTPRECISION > BTWPRECISION-2 ) {
		$perc = substr($perc, 0, length($perc) - (AMTPRECISION - BTWPRECISION-2))
	    }
	    elsif ( AMTPRECISION < BTWPRECISION-2 ) {
		$perc .= "0" x (BTWPRECISION-2 - AMTPRECISION);
	    }
	}
	elsif ( $extra =~ m/^tariefgroep=hoog$/i ) {
	    $groep = BTWTYPE_HOOG;
	}
	elsif ( $extra =~ m/^tariefgroep=laag$/i ) {
	    $groep = BTWTYPE_LAAG;
	}
	elsif ( $extra =~ m/^tariefgroep=geen$/i ) {
	    $groep = BTWTYPE_GEEN;
	}
	elsif ( $extra =~ m/^incl(?:usief)?$/i ) {
	    $incl = 1;
	}
	elsif ( $extra =~ m/^excl(?:usief)?$/i ) {
	    $incl = 0;
	}
	else {
	    error("BTW tarief $id: onbekende info \"$extra\"\n");
	}
    }

    error("BTW tarief $id: geen percentage en de tariefgroep is niet \"geen\"\n")
      unless defined($perc) || $groep == BTWTYPE_GEEN;

    $btw[$id] = [ $id, $desc, $groep, $perc, $incl ];

    if ( $groep == BTWTYPE_GEEN && !defined($btwmap{g}) ) {
	$btwmap{g} = $id;
    }
    elsif ( $incl ) {
	if ( $groep == BTWTYPE_HOOG && !defined($btwmap{h}) ) {
	    $btwmap{h} = $id;
	}
	elsif ( $groep == BTWTYPE_LAAG && !defined($btwmap{l}) ) {
	    $btwmap{l} = $id;
	}
    }
    1;
}

sub scan_balres {
    my ($balres) = shift;
    if ( /^\s*(\d)\s+(.+)/ ) {
	error("Dubbel: hoofdverdichting $1\n") if exists($hvdi[$1]);
	$hvdi[$chvdi = $1] = [ $2, $balres ];
    }
    elsif ( /^\s*(\d\d)\s+(.+)/ ) {
	error("Dubbel: verdichting $1\n") if exists($vdi[$1]);
	error("Verdichting $1 heeft geen hoofdverdichting\n") unless defined($chvdi);
	$vdi[$cvdi = $1] = [ $2, $balres, $chvdi ];
    }
    elsif ( /^\s*(\d\d\d+)\s+(\S+)\s+(.+)/ ) {
	my ($id, $flags, $desc) = ($1, $2, $3);
	error("Dubbel: rekening $1\n") if exists($acc{$id});
	error("Rekening $id heeft geen verdichting\n") unless defined($cvdi);
	error("Rekening $id: onherkenbare vlaggetjes $flags\n")
	  unless $flags =~ /^[dc][ko]$/i;
	my $debcrd = $flags =~ /^d/i;
	my $kstomz = $flags =~ /^.k/i;

	my $btw = 'g';
	my $extra;
	while ( $desc =~ /^(.+?)\s+:([^\s:]+)\s*$/ ) {
	    $desc = $1;
	    $extra = $2;
	    if ( $extra =~ m/^btw=(hoog|laag)$/i ) {
		$btw = lc(substr($1,0,1));
	    }
	    elsif ( $extra =~ m/koppeling=(\S+)/i ) {
		error("Rekening $id: onbekende koppeling \"$1\"\n")
		  unless exists($std{$1});
		error("Rekening $id: extra koppeling voor \"$1\"\n")
		  if $std{$1};
		$std{$1} = $id;
	    }
	}
	$desc =~ s/\s+$//;
	$acc{$id} = [ $desc, $cvdi, $balres, $debcrd, $kstomz, $btw ];
    }
    else {
	0;
    }
}

sub scan_balans {
    unshift(@_, 1);
    goto &scan_balres;
}

sub scan_result {
    unshift(@_, 0);
    goto &scan_balres;
}

sub load_schema {

    my $scanner;		# current scanner

    %std = map { $_ => 0 } qw(btw_ok btw_vh winst crd deb btw_il btw_vl btw_ih);
    $fh ||= *ARGV;
    while ( <$fh> ) {
	next if /^\s*#/;
	next unless /\S/;

	if ( /^balans/i ) {
	    $scanner = \&scan_balans;
	    next;
	}
	if ( /^result/i ) {
	    $scanner = \&scan_result;
	    next;
	}
	if ( /^dagboeken/i ) {
	    $scanner = \&scan_dagboeken;
	    next;
	}
	if ( /^btw\s*tarieven/i ) {
	    $scanner = \&scan_btw;
	    next;
	}
	if ( $scanner ) {
	    chomp;
	    $scanner->() or
	      error("Ongeldige invoer: $_ (regel $.)\n");
	    next;
	}

	error("?Men beginne met \"Balansrekeningen\", \"Resultaatrekeningen\",".
	      " \"Dagboeken\" of \"BTW Tarieven\"\n");
    }

    while ( my($k,$v) = each(%std) ) {
	next if $v;
	error("Geen koppeling gevonden voor \"$k\"\n");
    }

    my %mapbtw = ( g => "Geen", h => "Hoog", "l" => "Laag" );
    foreach ( keys(%mapbtw) ) {
	next if defined($btwmap{$_});
	error("Geen BTW tarief gevonden met tariefgroep ",
	      $mapbtw{$_}, 
	      ", inclusief\n");
    }
    die("?FOUTEN GEVONDEN, VERWERKING AFGEBROKEN\n") if $fail;

    if ( $sql ) {
	gen_schema();
    }
    else {
	create_schema();
    }
}

sub create_schema {
    sql(sql_eekboek());
    $dbh->commit;
}

sub sql_eekboek {
    my $f = $ENV{EB_LIB} . "/schemas/eekboek.sql";
    open (my $fh, '<', $f)
      or die("Installation error -- no master schema\n");

    local $/;
    $sql = <$fh>;
    close($fh);
    $sql;
}

sub sql_constants {
    my $out = "COPY Constants (name, value) FROM stdin;\n";

    foreach my $key ( sort(@EB::Globals::EXPORT) ) {
	no strict;
	next if ref($key->());
	$out .= "$key\t" . $key->() . "\n";
    }
    $out . "\\.\n";
}

sub sql_vrd {
    my $out = <<ESQL;
-- Hoofdverdichtingen
COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;
ESQL

    for ( my $i = 0; $i < @hvdi; $i++ ) {
	next unless exists $hvdi[$i];
	my $v = $hvdi[$i];
	$out .= join("\t", $i, $v->[0], _tf($v->[1]), "\\N", "\\N") . "\n";
    }
    $out .= "\\.\n";

    $out .= <<ESQL;

-- Verdichtingen
COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;
ESQL

    for ( my $i = 0; $i < @vdi; $i++ ) {
	next unless exists $vdi[$i];
	my $v = $vdi[$i];
	$out .= join("\t", $i, $v->[0], _tf($v->[1]), "\\N", $v->[2]) . "\n";
    }
    $out . "\\.\n";
}

sub sql_acc {
    my $out = <<ESQL;
-- Grootboekrekeningen
COPY Accounts
     (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd,
      acc_kstomz, acc_btw, acc_ibalance, acc_balance)
     FROM stdin;
ESQL

    for my $i ( sort { $a <=> $b } keys(%acc) ) {
	my $g = $acc{$i};
	$out .= join("\t", $i, $g->[0], $g->[1],
		     _tf($g->[2]),
		     _tf($g->[3]),
		     _tf($g->[4]),
		     $btwmap{$g->[5]},
		     0, 0) . "\n";
    }
    $out . "\\.\n";
}

sub sql_std {
    my $out = <<ESQL;
-- Standaardrekeningen
INSERT INTO Standaardrekeningen
ESQL
    $out .= "  (" . join(", ", map { "std_acc_$_" } keys(%std)) . ")\n";
    $out .= "  VALUES (" . join(", ", values(%std)) . ");\n";

    $out;
}

sub sql_btw {
    my $out = <<ESQL;
-- BTW Tarieven
COPY BTWTabel (btw_id, btw_desc, btw_tariefgroep, btw_perc, btw_incl) FROM stdin;
ESQL

    foreach ( @btw ) {
	next unless defined;
	if ( $_->[2] == BTWTYPE_GEEN ) {
	    $_->[3] = 0;
	    $_->[4] = "\\N";
	}
	else {
	    $_->[4] = _tf($_->[4]);
	}
	$out .= join("\t", @$_) . "\n";
    }
    $out . "\\.\n";
}

sub sql_dbk {
    my $out = <<ESQL;
-- Dagboeken
COPY Dagboeken (dbk_id, dbk_desc, dbk_type, dbk_acc_id) FROM stdin;
ESQL

    foreach ( @dbk ) {
	next unless defined;
	$_->[3] = $std{deb} if $_->[2] == DBKTYPE_VERKOOP;
	$_->[3] = $std{crd} if $_->[2] == DBKTYPE_INKOOP;
	$out .= join("\t",
		     map { defined($_) ? $_ : "\\N" } @$_).
		       "\n";
    }
    $out .= "\\.\n";

    $out .= "\n-- Sequences for Boekstuknummers, one for each Dagboek\n";
    foreach ( @dbk ) {
	next unless defined;
	$out .= "CREATE SEQUENCE bsk_nr_$_->[0]_seq;\n";
    }
    $out;
}

sub gen_schema {
    foreach ( qw(eekboek vrd acc dbk btw std) ) {
	warn('%'."Aanmaken $_.sql...\n");
	open(my $f, ">$_.sql") or die("Cannot create $_.sql: $!\n");
	my $cmd = "sql_$_";
	no strict 'refs';
	print $f $cmd->();
	close($f);
    }
}

sub _tf {
    qw(f t)[shift];
}

# Basic SQL processor. Not very advanced, but does the job.
# Currently only for PostgreSQL, but easily extensible for other databases as well.
# Note that COPY status will not work across different \i providers.
# COPY status need to be terminated on the same level it was started.

sub sql {
    my ($cmd, $copy) = (@_, 0);
    my $sql = "";

    foreach my $line ( split(/\n/, $cmd) ) {

	# Detect \i provider (include).
	if ( $line =~ /^\\i\s+(.*).sql/ ) {
	    my $call = "sql_$1";
	    no strict 'refs';
	    sql($call->(), $copy);
	    next;
	}

	# Handle COPY status.
	if ( $copy ) {
	    if ( $line eq "\\." ) {
		$dbh->dbh->pg_endcopy;
		$copy = 0;
	    }
	    else {
		$dbh->dbh->pg_putline($line."\n");
	    }
	    next;
	}

	# Ordinary lines.
	# Strip comments.
	$line =~ s/--.*$//m;
	# Ignore empty lines.
	next unless $line =~ /\S/;
	# Trim whitespace.
	$line =~ s/\s+/ /g;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	# Append to command string.
	$sql .= $line . " ";
	# Execute if trailing ;
	if ( $line =~ /(.+);$/ ) {
	    warn("+ $sql\n");
	    $dbh->dbh->do($sql);
	    # Check for COPY/
	    $copy = $sql =~ /^copy\s/i;
	    $sql = "";
	}
    }

    die("?Incomplete final SQL command: $sql\n") if $sql;
}

################ Stand-alone use (dump schema) ################

unless ( caller ) {
    ::dump_schema();
}

################ Subroutines ################

sub ::dump_sql {
    my ($schema) = @_;
    $sql = 1;
    create(undef, $schema);
}

my %kopp;

sub ::dump_schema {
    $dbh = EB::DB->new(trace => $trace);
    $dbh->connectdb;		# can't wait...

    print("# $my_package Rekeningschema voor ", $dbh->dbh->{Name}, "\n");

    my $sth = $dbh->sql_exec("SELECT * FROM Standaardrekeningen");
    my $rr = $sth->fetchrow_hashref;
    $sth->finish;
    while ( my($k,$v) = each(%$rr) ) {
	$k =~ s/^std_acc_//;
	$kopp{$v} = $k;
    }

    dump_acc(1);		# Balansrekeningen
    dump_acc(0);		# Resultaatrekeningen
    dump_dbk();			# Dagboeken
    dump_btw();			# BTW tarieven
}

sub dump_acc {
    my ($balres) = @_;

    print("\n", $balres ? "Balans" : "Resultaat", "rekeningen\n");

    my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
			     " FROM Verdichtingen".
			     " WHERE ".($balres?"":"NOT ")."vdi_balres".
			     " AND vdi_struct IS NULL".
			     " ORDER BY vdi_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc) = @$rr;
	printf("\n  %d  %s\n", $id, $desc);
	print("# HOOFDVERDICHTING MOET TUSSEN 1 EN 9 (INCL.) LIGGEN\n")
	  if $id > 9;
	my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
				 " FROM Verdichtingen".
				 " WHERE vdi_struct = ?".
				 " ORDER BY vdi_id", $id);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($id, $desc) = @$rr;
	    printf("     %-2d  %s\n", $id, $desc);
	    print("# VERDICHTING MOET TUSSEN 10 EN 99 (INCL.) LIGGEN\n")
	      if $id < 10 || $id > 99;
	    my $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balres, acc_debcrd, acc_kstomz, btw_tariefgroep".
				     " FROM Accounts, BTWTabel ".
				     " WHERE acc_struct = ?".
				     " AND btw_id = acc_btw".
				     " ORDER BY acc_id", $id);
	    while ( my $rr = $sth->fetchrow_arrayref ) {
		my ($id, $desc, $acc_balres, $acc_debcrd, $acc_kstomz, $btw) = @$rr;
		my $flags = "";
		$flags .= $acc_debcrd ? "D" : "C";
		$flags .= $acc_kstomz ? "K" : "O";
		my $extra = "";
		$extra .= " :btw=hoog" if $btw == BTWTYPE_HOOG;
		$extra .= " :btw=laag" if $btw == BTWTYPE_LAAG;
		$extra .= " :koppeling=".$kopp{$id} if exists($kopp{$id});
		$desc =~ s/^\s+//;
		$desc =~ s/\s+$//;
		my $t = sprintf("         %-4d  %-2s  %-40.40s  %s",
				$id, $flags, $desc,
				$extra);
		$t =~ s/\s+$//;
		print($t, "\n");
		print("# $id ZOU EEN BALANSREKENING MOETEN ZIJN\n")
		  if $acc_balres && !$balres;
		print("# $id ZOU EEN RESULTAATREKENING MOETEN ZIJN\n")
		  if !$acc_balres && $balres;
	    }
	}
    }
}

sub dump_btw {
    print("\nBTW Tarieven\n\n");
    my $sth = $dbh->sql_exec("SELECT btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl".
			     " FROM BTWTabel".
			     " ORDER BY btw_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc, $perc, $btg, $incl) = @$rr;
	my $extra = "";
	$extra .= " :tariefgroep=" . lc(BTWTYPES->[$btg]);
	if ( $btg != BTWTYPE_GEEN ) {
	    $extra .= " :perc=".btwfmt($perc);
	    $extra .= " :" . qw(exclusief inclusief)[$incl] unless $incl;
	}
	my $t = sprintf(" %3d  %-20s  %s",
			$id, $desc, $extra);
	$t =~ s/\s+$//;
	print($t, "\n");
    }
}

sub dump_dbk {
    print("\nDagboeken\n\n");
    my $sth = $dbh->sql_exec("SELECT dbk_id, dbk_desc, dbk_type, dbk_acc_id".
			     " FROM Dagboeken".
			     " ORDER BY dbk_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc, $type, $acc_id) = @$rr;
	$acc_id = 0 if $type == DBKTYPE_INKOOP || $type == DBKTYPE_VERKOOP;
	my $t = sprintf(" %3d  %-20s  :type=%-10s %s",
			$id, $desc, lc(DBKTYPES->[$type]),
			($acc_id ? ":rekening=$acc_id" : ""));
	$t =~ s/\s+$//;
	print($t, "\n");
    }
}

1;
