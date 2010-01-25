#! perl --			-*- coding: utf-8 -*-

use utf8;

# RCS Id          : $Id: Schema.pm,v 1.65 2010/01/25 17:36:59 jv Exp $
# Author          : Johan Vromans
# Created On      : Sun Aug 14 18:10:49 2005
# Last Modified By: Johan Vromans
# Last Modified On: Mon Jan 25 18:36:12 2010
# Update Count    : 774
# Status          : Unknown, Use with caution!

################ Common stuff ################

package main;

our $cfg;
our $dbh;

package EB::Tools::Schema;

use strict;
use warnings;

our $VERSION = sprintf "%d.%03d", q$Revision: 1.65 $ =~ /(\d+)/g;

our $sql = 0;			# load schema into SQL files
my $trace = $cfg->val(__PACKAGE__, "trace", 0);

my $RCS_Id = '$Id: Schema.pm,v 1.65 2010/01/25 17:36:59 jv Exp $ ';

# Package name.
my $my_package = 'EekBoek';
# Program name and version.
my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pm,v ([\d.]+)/;
# Tack '*' if it is not checked in into RCS.
$my_version .= '*' if length('$Locker:  $ ') > 12;

################ The Process ################

use EB;
use EB::Format;
use EB::DB;
use Encode;

################ Subroutines ################

################ Schema Loading ################

my $schema;

sub create {
    shift;			# singleton class method
    my ($name) = @_;
    my $file;
    if ( $name !~ /^\w+$/) {
	$file = $name;
    }
    else {
	foreach my $dir ( ".", "schema" ) {
	    foreach my $ext ( ".dat" ) {
		next unless -s "$dir/$name$ext";
		$file = "$dir/$name$ext";
		last;
	    }
	}
	$file = findlib("schema/$name.dat") unless $file;
    }

    die("?".__x("Onbekend schema: {schema}", schema => $name)."\n") unless $file;
    open(my $fh, "<", $file)
      or die("?".__x("Toegangsfout schema data: {err}", err => $!)."\n");
    $schema = $name;
    _create(undef, sub { <$fh> });
    __x("Schema {schema} geïnitialiseerd", schema => $name);
}

sub _create {
    shift;			# singleton class method
    my ($rl) = @_;
    $dbh = EB::DB->new(trace => $trace) unless $sql;
    load_schema($rl);
}

my @hvdi;			# hoofdverdichtingen
my @vdi;			# verdichtingen
my $max_hvd;			# hoogste waarde voor hoofdverdichting
my $max_vrd;			# hoogste waarde voor verdichting
my %acc;			# grootboekrekeningen
my $chvdi;			# huidige hoofdverdichting
my $cvdi;			# huidige verdichting
my %std;			# standaardrekeningen
my %dbk;			# dagboeken
my @dbk;			# dagboeken
my @btw;			# btw tarieven
my %btwmap;			# btw type/incl -> code
my $fail;			# any errors

sub init_vars {
    @hvdi = ();			# hoofdverdichtingen
    @vdi = ();			# verdichtingen
    undef $max_hvd;		# hoogste waarde voor hoofdverdichting
    undef $max_vrd;		# hoogste waarde voor verdichting
    %acc = ();			# grootboekrekeningen
    undef $chvdi;		# huidige hoofdverdichting
    undef $cvdi;		# huidige verdichting
    %std = ();			# standaardrekeningen
    %dbk = ();			# dagboeken
    @dbk = ();			# dagboeken
    @btw = ();			# btw tarieven
    %btwmap = ();		# btw type/incl -> code
    undef $fail;		# any errors
}

sub error { warn('?', @_); $fail++; }

my $dbkid;

sub scan_dagboeken {
    return 0 unless /^\s+(\w{1,4})\s+(.*)/ && $1;
    $dbkid++;

    my ($id, $desc) = ($1, $2);
    error(__x("Dubbel: dagboek {dbk}", dbk => $id)."\n") if defined($dbk{$id});

    my $type;
    my $dcsplit,
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
	    error(__x("Dagboek {id} onbekend type \"{type}\"",
		      id => $id, type => $1)."\n") unless defined($type);
	}
	elsif ( $extra =~ m/^rek(?:ening)?=(\d+)$/i ) {
	    $rek = $1;
	}
	elsif ( $extra =~ m/^dc$/i ) {
	    $dcsplit = 1;
	}
	else {
	    error(__x("Dagboek {id}: onbekende info \"{info}\"",
		      id => $id, info => $extra)."\n");
	}
    }

    error(__x("Dagboek {id}: het :type ontbreekt", id => $id)."\n") unless defined($type);
    error(__x("Dagboek {id}: het :rekening nummer ontbreekt", id => $id)."\n")
      if ( $type == DBKTYPE_KAS || $type == DBKTYPE_BANK ) && !$type;
    error(__x("Dagboek {id}: :dc is alleen toegestaan voor Kas en Bankboeken", id => $id)."\n")
      if $dcsplit && !( $type == DBKTYPE_KAS || $type == DBKTYPE_BANK );
#    error(__x("Dagboek {id}: rekeningnummer enkel toegestaan voor Kas en Bankboeken", id => $id)."\n")
#      if $rek && !($type == DBKTYPE_KAS || $type == DBKTYPE_BANK || $type == DBKTYPE_MEMORIAAL);

    $dbk{$id} = $dbkid;
    $dbk[$dbkid] = [ $id, $desc, $type, $dcsplit, $rek||undef ];
}

sub scan_btw {
    return 0 unless /^\s+(\d+)\s+(.*)/;

    my ($id, $desc) = ($1, $2);
    error(__x("Dubbel: BTW tarief {id}", id => $id)."\n") if defined($btw[$id]);

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
	    $groep = BTWTARIEF_HOOG;
	}
	elsif ( $extra =~ m/^tariefgroep=laag$/i ) {
	    $groep = BTWTARIEF_LAAG;
	}
	elsif ( $extra =~ m/^tariefgroep=(nul|geen)$/i ) {
	    $groep = BTWTARIEF_NUL;
	    warn("!"._T("Gelieve BTW tariefgroep \"Geen\" te vervangen door \"Nul\"")."\n")
	      if lc($1) eq "geen";
	}
	elsif ( $extra =~ m/^tariefgroep=priv(e|é)?$/i ) {
	    $groep = BTWTARIEF_PRIV;
	}
	elsif ( $extra =~ m/^tariefgroep=anders??$/i ) {
	    $groep = BTWTARIEF_ANDERS;
	}
	elsif ( $extra =~ m/^incl(?:usief)?$/i ) {
	    $incl = 1;
	}
	elsif ( $extra =~ m/^excl(?:usief)?$/i ) {
	    $incl = 0;
	}
	else {
	    error(__x("BTW tarief {id}: onbekende info \"{info}\"",
		      id => $id, info => $extra)."\n");
	}
    }

    error(__x("BTW tarief {id}: geen percentage en de tariefgroep is niet \"{none}\"",
	      id => $id, none => _T("geen"))."\n")
      unless defined($perc) || $groep == BTWTARIEF_NUL;

    $btw[$id] = [ $id, $desc, $groep, $perc, $incl ];

    if ( $groep == BTWTARIEF_NUL && !defined($btwmap{n}) ) {
	$btwmap{n} = $id;
    }
    elsif ( $incl ) {
	if ( $groep == BTWTARIEF_HOOG && !defined($btwmap{h}) ) {
	    $btwmap{h} = $id;
	}
	elsif ( $groep == BTWTARIEF_LAAG && !defined($btwmap{l}) ) {
	    $btwmap{l} = $id;
	}
	elsif ( $groep == BTWTARIEF_PRIV && !defined($btwmap{p}) ) {
	    $btwmap{p} = $id;
	}
	elsif ( $groep == BTWTARIEF_ANDERS && !defined($btwmap{a}) ) {
	    $btwmap{a} = $id;
	}
    }
    else {
	if ( $groep == BTWTARIEF_HOOG && !defined($btwmap{"h-"}) ) {
	    $btwmap{"h-"} = $id;
	}
	elsif ( $groep == BTWTARIEF_LAAG && !defined($btwmap{"l-"}) ) {
	    $btwmap{"l-"} = $id;
	}
	elsif ( $groep == BTWTARIEF_PRIV && !defined($btwmap{"p-"}) ) {
	    $btwmap{"p-"} = $id;
	}
	elsif ( $groep == BTWTARIEF_ANDERS && !defined($btwmap{"a-"}) ) {
	    $btwmap{"a-"} = $id;
	}
    }
    $btwmap{$id} = $id;
    1;
}

sub scan_balres {
    my ($balres) = shift;
    if ( /^\s*(\d+)\s+(.+)/ && length($1) <= length($max_hvd) && $1 <= $max_hvd ) {
	error(__x("Dubbel: hoofdverdichting {vrd}", vrd => $1)."\n") if exists($hvdi[$1]);
	$hvdi[$chvdi = $1] = [ $2, $balres ];
    }
    elsif ( /^\s*(\d+)\s+(.+)/ && length($1) <= length($max_vrd) && $1 <= $max_vrd ) {
	error(__x("Dubbel: verdichting {vrd}", vrd => $1)."\n") if exists($vdi[$1]);
	error(__x("Verdichting {vrd} heeft geen hoofdverdichting", vrd => $1)."\n") unless defined($chvdi);
	$vdi[$cvdi = $1] = [ $2, $balres, $chvdi ];
    }
    elsif ( /^\s*(\d+)\s+(\S+)\s+(.+)/ ) {
	my ($id, $flags, $desc) = ($1, $2, $3);
	error(__x("Dubbel: rekening {acct}", acct => $1)."\n") if exists($acc{$id});
	error(__x("Rekening {id} heeft geen verdichting", id => $id)."\n") unless defined($cvdi);
	my $debcrd;
	my $kstomz;
	my $dcfixed;
	if ( ($balres ? $flags =~ /^[dc]\!?$/i : $flags =~ /^[kon]$/i)
	     ||
	     $flags =~ /^[dc][ko]$/i ) {
	    $debcrd = $flags =~ /d/i;
	    $kstomz = $flags =~ /k/i if $flags =~ /[ko]/i;
	    $dcfixed = $flags =~ /\!/;
	}
	else {
	    error(__x("Rekening {id}: onherkenbare vlaggetjes {flags}",
		      id => $id, flags => $flags)."\n");
	}

	my $btw_type = 'n';
	my $btw_ko;
	my $extra;

	while ( $desc =~ /^(.+?)\s+:([^\s:]+)\s*$/ ) {
	    $desc = $1;
	    $extra = $2;
	    if ( $extra =~ m/^btw=(.+)$/i ) {
		my $spec = $1;
		my @spec = split(/,/, lc($spec));

		my $btw_inex = 1;

		foreach ( @spec ) {
		    if ( $balres && /^(kosten|omzet)$/ ) {
			$btw_ko = substr($1, 0, 1) eq "k";
		    }
		    elsif ( /^(hoog|laag|nul|priv(e|é)?|anders?)$/ ) {
			$btw_type = substr($1, 0, 1);
		    }
		    elsif ( /^\d+$/ ) {
			$btw_type = $_;
		    }
		    elsif ( $_ eq "geen" ) {
			$btw_type = 0;
			$kstomz = $btw_ko = undef;
		    }
		    elsif ( /^(incl|excl)(usief)?$/ ) {
			$btw_inex = substr($1, 1, 1) eq 'i';
		    }
		    else {
			error(__x("Foutieve BTW specificatie: {spec}",
				  spec => $spec)."\n");
			last;
		    }
		}

		$btw_type .= "-" unless $btw_inex;
	    }
	    elsif ( $extra =~ m/koppeling=(\S+)/i ) {
		error(__x("Rekening {id}: onbekende koppeling \"{std}\"",
			  id => $id, std => $1)."\n")
		  unless exists($std{$1});
		error(__x("Rekening {id}: extra koppeling voor \"{std}\"",
			  id => $id, std => $1)."\n")
		  if $std{$1};
		$std{$1} = $id;
	    }
	}
	if ( $btw_type ne 'n' ) {
	    error(__x("Rekening {id}: BTW koppeling '{ko}' met een {acc} is niet toegestaan",
		      id => $id, ko => qw(omzet kosten)[$btw_ko],
		      acc => qw(omzetrekening kostenrekening)[$kstomz])."\n")
	      if !$balres && defined($kstomz) && defined($btw_ko) && $btw_ko != $kstomz;
	    error(__x("Rekening {id}: BTW koppeling met neutrale resultaatrekening is niet toegestaan",
		      id => $id)."\n") unless defined($kstomz) || defined($btw_ko);
	    error(__x("Rekening {id}: BTW koppeling met een balansrekening vereist kosten/omzet specificatie",
		      id => $id)."\n")
	      if $balres && !defined($btw_ko);
	}
	$desc =~ s/\s+$//;
	$kstomz = $btw_ko unless defined($kstomz);
	$acc{$id} = [ $desc, $cvdi, $balres, $debcrd, $kstomz, $btw_type, $dcfixed ];
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
    my ($rl) = shift;

    init_vars();
    my $scanner;		# current scanner
    $max_hvd = 9;
    $max_vrd = 99;
    my $uerr = 0;

    %std = map { $_ => 0 } qw(btw_ok btw_vh winst crd deb btw_il btw_vl btw_ih btw_vp btw_ip btw_va btw_ia);
    while ( $_ = $rl->() ) {
	if ( /^\# \s*
	      content-type: \s*
              text (?: \s* \/ \s* plain)? \s* ; \s*
              charset \s* = \s* (\S+) \s* $/ix ) {
	    my $charset = lc($1);
	    if ( $charset =~ /^(?:utf-?8)$/i ) {
		next;
	    }
	    error(_T("Invoer moet Unicode (UTF-8) zijn.")."\n");
	}

	my $s = "".$_;
	eval {
	    $_ = decode('utf8', $s, 1);
	};
	if ( $@ ) {
	    warn("?".__x("Geen geldige UTF-8 tekens in regel {line} van de invoer",
			 line => $.)."\n".$s."\n");
	    warn($@);
	    $fail++;
	    next;
	}

	next if /^\s*#/;
	next unless /\S/;

	# Scanner selectie.
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

	# Overige settings.
	if ( /^verdichting\s+(\d+)\s+(\d+)/i && $1 < $2 ) {
	    $max_hvd = $1;
	    $max_vrd = $2;
	    next;
	}

	# Anders: Scan.
	if ( $scanner ) {
	    chomp;
	    $scanner->() or
	      error(__x("Ongeldige invoer: {line} (regel {lno})",
			line => $_, lno => $.)."\n");
	    next;
	}

	error("?"._T("Men beginne met \"Balansrekeningen\", \"Resultaatrekeningen\",".
		     " \"Dagboeken\" of \"BTW Tarieven\"")."\n");
    }

    # Bekijk alle dagboeken om te zien of er inkoop/verkoop dagboeken
    # zijn die een tegenrekening nodig hebben. In dat geval moet de
    # betreffende koppeling in het schema gemaakt zijn.
    my ($need_deb, $need_crd) = (0,0);
    foreach ( @dbk ) {
	next unless defined($_); # sparse
	my ($id, $desc, $type, $dc, $rek) = @$_;
	next if defined($rek);
	if ( $type == DBKTYPE_INKOOP ) {
	    $need_crd++;
	    $_->[4] = $std{"crd"};
	    #### Verify that it's a C acct.
	}
	elsif ( $type == DBKTYPE_VERKOOP ) {
	    $need_deb++;
	    $_->[4] = $std{"deb"};
	    #### Verify that it's a D acct.
	}
	elsif ( $type != DBKTYPE_MEMORIAAL ) {
	    error(__x("Dagboek {id} heeft geen tegenrekening", id => $id)."\n");
	    $fail++;
	}
    }
    # Verwijder onnodige koppelingen.
    delete($std{crd}) unless $need_crd;
    delete($std{deb}) unless $need_deb;

    unless (defined($btwmap{p}) || defined($btwmap{"p-"}) ) {
	delete($std{"btw_ip"}) unless $std{"btw_ip"};
	delete($std{"btw_vp"}) unless $std{"btw_vp"};
    }
    unless (defined($btwmap{a}) || defined($btwmap{"a-"}) ) {
	delete($std{"btw_ia"}) unless $std{"btw_ia"};
	delete($std{"btw_va"}) unless $std{"btw_va"};
    }

    my %mapbtw = ( n => "Nul", h => "Hoog", "l" => "Laag" );
    if ( @btw ) {
	foreach ( keys(%mapbtw) ) {
	    next if defined($btwmap{$_});
	    error(__x("Geen BTW tarief gevonden met tariefgroep {gr}, inclusief",
		      gr => $mapbtw{$_})."\n");
	}
    }
    else {
	for ( qw(ih il ip ia vh vl vp va ok) ) {
	    delete($std{"btw_$_"}) unless $std{"btw_$_"};
	}
	$btwmap{n} = undef;
	$btw[0] = [ 0, "BTW Nul", BTWTARIEF_NUL, 0, 0 ];
    }
    while ( my($k,$v) = each(%std) ) {
	next if $v;
	error(__x("Geen koppeling gevonden voor \"{std}\"", std => $k)."\n");
    }

    die("?"._T("FOUTEN GEVONDEN, VERWERKING AFGEBROKEN")."\n") if $fail;

    if ( $sql ) {
	gen_schema();
    }
    else {
	create_schema();
    }
}

sub create_schema {
    use EB::Tools::SQLEngine;
    my $engine = EB::Tools::SQLEngine->new(trace => $trace);
    $engine->callback(map { $_, __PACKAGE__->can("sql_$_") } qw(constants vrd acc std btw dbk) );
    $dbh->begin_work;
    $engine->process(sql_eekboek());
    $dbh->commit;
}

sub _trim {
    my ($t) = @_;
    for ( $t ) {
	s/\s+/ /g;
	s/^\s+//;
	s/\s+$//;
	return $_;
    }
}

sub _tsv {
    join("\t", map { _trim($_) } @_) . "\n";
}

sub sql_eekboek {
    my $f = findlib("schema/eekboek.sql");
    open (my $fh, '<:encoding(utf-8)', $f)
      or die("?"._T("Installatiefout -- geen database schema")."\n");

    local $/;
    my $sql = <$fh>;
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
	$out .= _tsv($i, $v->[0], _tf($v->[1]), _tfn(undef), "\\N");
    }
    $out .= "\\.\n";

    $out .= <<ESQL;

-- Verdichtingen
COPY Verdichtingen (vdi_id, vdi_desc, vdi_balres, vdi_kstomz, vdi_struct) FROM stdin;
ESQL

    for ( my $i = 0; $i < @vdi; $i++ ) {
	next unless exists $vdi[$i];
	my $v = $vdi[$i];
	$out .= _tsv($i, $v->[0], _tf($v->[1]), _tfn(undef), $v->[2]);
    }
    $out . "\\.\n";
}

sub sql_acc {
    my $out = <<ESQL;
-- Grootboekrekeningen
COPY Accounts
     (acc_id, acc_desc, acc_struct, acc_balres, acc_debcrd, acc_dcfixed,
      acc_kstomz, acc_btw, acc_ibalance, acc_balance)
     FROM stdin;
ESQL

    for my $i ( sort { $a <=> $b } keys(%acc) ) {
	my $g = $acc{$i};
	croak(__x("Geen BTW tariefgroep voor code {code}",
		  code => $g->[5]))
	  unless exists $btwmap{$g->[5]} || exists $btwmap{$g->[5]."-"};
	$out .= _tsv($i, $g->[0], $g->[1],
		     _tf($g->[2]),
		     _tf($g->[3]),
		     _tfn($g->[2] ? $g->[6] : undef),
		     _tfn($g->[4]),
		     defined($btwmap{$g->[5]}) ? $btwmap{$g->[5]} : "\\N",
		     0, 0);
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
	if ( $_->[2] == BTWTARIEF_NUL ) {
	    $_->[3] = 0;
	    $_->[4] = "\\N";
	}
	else {
	    $_->[4] = _tf($_->[4]);
	}
	$out .= _tsv(@$_);
    }
    $out . "\\.\n";
}

sub sql_dbk {
    my $out = <<ESQL;
-- Dagboeken
COPY Dagboeken (dbk_id, dbk_desc, dbk_type, dbk_dcsplit, dbk_acc_id) FROM stdin;
ESQL

    foreach ( @dbk ) {
	next unless defined;
	$_->[4] ||= $std{deb} if $_->[2] == DBKTYPE_VERKOOP;
	$_->[4] ||= $std{crd} if $_->[2] == DBKTYPE_INKOOP;
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

use Encode;
sub gen_schema {
    foreach ( qw(eekboek vrd acc dbk btw std) ) {
	warn('%'.__x("Aanmaken {sql}...",
		     sql => "$_.sql")."\n");

	# Careful. Data is utf8.
	open(my $f, ">:encoding(utf-8)", "$_.sql")
	  or die("Cannot create $_.sql: $!\n");
	my $cmd = "sql_$_";
	no strict 'refs';
	print $f decode_utf8($cmd->());
	close($f);
    }
}

sub _tf {
    qw(f t)[shift];
}

sub _tfn {
    defined($_[0]) ? qw(f t)[$_[0]] : "\\N";
}

################ Subroutines ################

sub dump_sql {
    my ($self, $schema) = @_;
    local($sql) = 1;
    create(undef, $schema);
}

my %kopp;
my $fh;

sub dump_schema {
    my ($self, $fh) = @_;
    $fh ||= *STDOUT;

    $dbh = EB::DB->new(trace => $trace);
    $dbh->connectdb;		# can't wait...

    print {$fh} ("# $my_package Rekeningschema voor ", $dbh->dbh->{Name}, "\n",
	  "# Aangemaakt door ", __PACKAGE__, " $my_version");
    my @t = localtime(time);
    printf {$fh} (" op %02d-%02d-%04d %02d:%02d:%02d\n", $t[3], 1+$t[4], 1900+$t[5], @t[2,1,0]);
    print {$fh} ("# Content-Type: text/plain; charset = UTF-8\n");
    print {$fh}  <<EOD;

# Dit bestand definiëert alle vaste gegevens van een administratie of
# groep administraties: het rekeningschema (balansrekeningen en
# resultaatrekeningen), de dagboeken en de BTW tarieven.
#
# Algemene syntaxregels:
#
# * Lege regels en regels die beginnen met een hekje # worden niet
#   geïnterpreteerd.
# * Een niet-ingesprongen tekst introduceert een nieuw onderdeel.
# * Alle ingesprongen regels zijn gegevens voor dat onderdeel.

EOD

    my $sth = $dbh->sql_exec("SELECT * FROM Standaardrekeningen");
    my $rr = $sth->fetchrow_hashref;
    $sth->finish;
    while ( my($k,$v) = each(%$rr) ) {
	next unless defined $v;
	$k =~ s/^std_acc_//;
	$kopp{$v} = $k;
    }

print {$fh}  <<EOD;
# REKENINGSCHEMA
#
# Het rekeningschema is hiërarchisch opgezet volgende de beproefde
# methode Bakker. De hoofdverdichtingen lopen van 1 t/m 9, de
# verdichtingen t/m 99. De grootboekrekeningen zijn verdeeld in
# balansrekeningen en resultaatrekeningen.
#
# De omschrijving van de grootboekrekeningen wordt voorafgegaan door
# een vlaggetje, een letter die resp. Debet/Credit (voor
# balansrekeningen) en Kosten/Omzet/Neutraal (voor resultaatrekeningen)
# aangeeft. De omschrijving wordt indien nodig gevolgd door extra
# informatie. Voor grootboekrekeningen kan op deze wijze de BTW
# tariefstelling worden aangegeven die op deze rekening van toepassing
# is:
#
#   :btw=nul
#   :btw=hoog
#   :btw=laag
#   :btw=privé
#   :btw=anders
#
# Ook is het mogelijk aan te geven dat een rekening een koppeling
# (speciale betekenis) heeft met :koppeling=xxx. De volgende koppelingen
# zijn mogelijk:
#
#   crd		de standaard tegenrekening (Crediteuren) voor inkoopboekingen
#   deb		de standaard tegenrekening (Debiteuren) voor verkoopboekingen
#   btw_ih	de rekening voor BTW boekingen voor inkopen, hoog tarief
#   btw_il	idem, laag tarief
#   btw_vh	idem, verkopen, hoog tarief
#   btw_vl	idem, laag tarief
#   btw_ph	idem, privé, hoog tarief
#   btw_pl	idem, laag tarief
#   btw_ah	idem, anders, hoog tarief
#   btw_al	idem, laag tarief
#   btw_ok	rekening voor de betaalde BTW
#   winst	rekening waarop de winst wordt geboekt
#
# De koppeling winst is verplicht en moet altijd in een administratie
# voorkomen in verband met de jaarafsluiting.
# De koppelingen voor BTW moeten worden opgegeven indien BTW
# van toepassing is op de administratie.
# De koppelingen voor Crediteuren en Debiteuren moeten worden
# opgegeven indien er inkoop dan wel verkoopdagboeken zijn die gebruik
# maken van de standaardwaarden (dus zelf geen tegenrekening hebben
# opgegeven).
EOD

$max_hvd = $dbh->do("SELECT MAX(vdi_id) FROM Verdichtingen WHERE vdi_struct IS NULL")->[0];
$max_vrd = $dbh->do("SELECT MAX(vdi_id) FROM Verdichtingen WHERE NOT vdi_struct IS NULL")->[0];

    print {$fh}  <<EOD;

# Normaal lopen hoofdverdichtingen van 1 t/m 9, en verdichtingen
# van 10 t/m 99. Indien daarvan wordt afgeweken kan dit worden opgegeven
# met de opdracht "Verdichting". De twee getallen geven het hoogste
# nummer voor hoofdverdichtingen resp. verdichtingen.
EOD

    if ( $max_hvd > 9 || $max_vrd > 99 ) {
	printf {$fh} ("\nVerdichting %d %d\n", $max_hvd, $max_vrd);
    }

    print {$fh}  <<EOD;
# De nummers van de grootboekrekeningen worden geacht groter te zijn
# dan de maximale verdichting. Daarvan kan worden afgeweken door
# middels voorloopnullen de _lengte_ van het nummer groter te maken
# dan de lengte van de maximale verdichting. Als bijvoorbeeld 99 de
# maximale verdichting is, dan geeft 001 een grootboekrekening met
# nummer 1 aan.
EOD

    dump_acc(1, $fh);		# Balansrekeningen
    dump_acc(0, $fh);		# Resultaatrekeningen

print {$fh}  <<EOD;

# DAGBOEKEN
#
# EekBoek ondersteunt vijf soorten dagboeken: Kas, Bank, Inkoop,
# Verkoop en Memoriaal. Er kunnen een in principe onbeperkt aantal
# dagboeken worden aangemaakt.
# In de eerste kolom wordt de korte naam (code) voor het dagboek
# opgegeven. Verder moet voor elk dagboek worden opgegeven van welk
# type het is. Voor dagboeken van het type Kas en Bank moet een
# tegenrekening worden opgegeven, voor de overige dagboeken mag een
# tegenrekening worden opgegeven.
# De optie :dc kan worden gebruikt om aan te geven dat het journaal
# voor dit dagboek de boekstuktotalen in gescheiden debet en credit
# moet tonen.
EOD

    dump_dbk($fh);			# Dagboeken

    if ( $dbh->does_btw ) {
	print {$fh}  <<EOD;

# BTW TARIEVEN
#
# Er zijn vijf tariefgroepen: "hoog", "laag", "nul", "privé" en
# "anders". De tariefgroep bepaalt het rekeningnummer waarop de
# betreffende boeking plaatsvindt.
# Binnen elke tariefgroep zijn meerdere tarieven mogelijk, hoewel dit
# in de praktijk niet snel zal voorkomen.
# In de eerste kolom wordt de (numerieke) code voor dit tarief
# opgegeven. Deze kan o.m. worden gebruikt om expliciet een BTW tarief
# op te geven bij het boeken. Voor elk gebruikt tarief (behalve die
# van groep "nul") moet het percentage worden opgegeven. Met de
# aanduiding :exclusief kan worden opgegeven dat boekingen op
# rekeningen met deze tariefgroep standaard het bedrag exclusief BTW
# aangeven.
#
# BELANGRIJK: Mutaties die middels de command line shell of de API
# worden uitgevoerd maken gebruik van het geassocieerde BTW tarief van
# de grootboekrekeningen. Wijzigingen hierin kunnen dus consequenties
# hebben voor de reeds in scripts vastgelegde boekingen.
EOD

	dump_btw($fh);			# BTW tarieven
    }
print {$fh}  <<EOD;

# Einde EekBoek schema
EOD
}

sub dump_acc {
    my ($balres, $fh) = @_;

    print {$fh} ("\n", $balres ? "Balans" : "Resultaat", "rekeningen\n");

    my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
			     " FROM Verdichtingen".
			     " WHERE ".($balres?"":"NOT ")."vdi_balres".
			     " AND vdi_struct IS NULL".
			     " ORDER BY vdi_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc) = @$rr;
	printf {$fh} ("\n  %d  %s\n", $id, $desc);
	print {$fh} ("# ".__x("HOOFDVERDICHTING MOET TUSSEN {min} EN {max} (INCL.) LIGGEN",
		       min => 1, max => $max_hvd)."\n")
	  if $id > $max_hvd;
	my $sth = $dbh->sql_exec("SELECT vdi_id, vdi_desc".
				 " FROM Verdichtingen".
				 " WHERE vdi_struct = ?".
				 " ORDER BY vdi_id", $id);
	while ( my $rr = $sth->fetchrow_arrayref ) {
	    my ($id, $desc) = @$rr;
	    printf {$fh} ("     %-2d  %s\n", $id, $desc);
	    print {$fh} ("# ".__x("VERDICHTING MOET TUSSEN {min} EN {max} (INCL.) LIGGEN",
			   min => $max_hvd+1, max => $max_vrd)."\n")
	      if $id <= $max_hvd || $id > $max_vrd;
	    my $sth = $dbh->sql_exec("SELECT acc_id, acc_desc, acc_balres,".
				     " acc_debcrd, acc_dcfixed, acc_kstomz,".
				     " acc_btw, btw_tariefgroep, btw_incl".
				     " FROM Accounts, BTWTabel ".
				     " WHERE acc_struct = ?".
				     " AND (btw_id = acc_btw".
				     " OR btw_id = 0 AND acc_btw IS NULL)".
				     " ORDER BY acc_id", $id);
	    while ( my $rr = $sth->fetchrow_arrayref ) {
		my ($id, $desc, $acc_balres, $acc_debcrd, $acc_dcfixed, $acc_kstomz, $btw_id, $btw, $btwincl) = @$rr;
		my $flags = "";
		if ( $balres ) {
		    $flags .= $acc_debcrd ? "D" : "C";
		    $flags .= '!' if $acc_dcfixed;
		}
		else {
		    $flags .= defined($acc_kstomz)
		      ? ($acc_kstomz ? "K" : "O")
			: "N";
		}
		my $extra = "";
		if ( $btw == BTWTARIEF_HOOG ) {
		    $extra .= " :btw=hoog";
		    $extra .= ",excl" unless $btwincl;
		    if ( $balres ) {
			$extra .= ",kosten" if $acc_kstomz;
			$extra .= ",omzet"  if !$acc_kstomz;
		    }
		}
		elsif ( $btw == BTWTARIEF_LAAG ) {
		    $extra .= " :btw=laag";
		    $extra .= ",excl" unless $btwincl;
		    if ( $balres ) {
			$extra .= ",kosten" if $acc_kstomz;
			$extra .= ",omzet"  if !$acc_kstomz;
		    }
		}
		elsif ( $btw == BTWTARIEF_PRIV ) {
		    $extra .= " :btw=privé";
		    $extra .= ",excl" unless $btwincl;
		    if ( $balres ) {
			$extra .= ",kosten" if $acc_kstomz;
			$extra .= ",omzet"  if !$acc_kstomz;
		    }
		}
		elsif ( $btw == BTWTARIEF_ANDERS ) {
		    $extra .= " :btw=anders";
		    $extra .= ",excl" unless $btwincl;
		    if ( $balres ) {
			$extra .= ",kosten" if $acc_kstomz;
			$extra .= ",omzet"  if !$acc_kstomz;
		    }
		}
		elsif ( $btw != BTWTARIEF_NUL ) {
		    $extra .= " :btw=$btw_id";
		}
		else {
		    if ( $balres && defined($acc_kstomz) ) {
			$extra .= " :btw=kosten" if $acc_kstomz;
			$extra .= " :btw=omzet"  if !$acc_kstomz;
		    }
		}
		$extra .= " :koppeling=".$kopp{$id} if exists($kopp{$id});
		$desc =~ s/^\s+//;
		$desc =~ s/\s+$//;
		my $t = sprintf("         %-4s  %-2s  %-40.40s  %s",
				$id < $max_vrd ? (("0" x (length($max_vrd)-length($id)+1)) . $id) : $id,
				$flags, $desc, $extra);
		$t =~ s/\s+$//;
		print {$fh} ($t, "\n");
		print {$fh} ("# ".__x("{id} ZOU EEN BALANSREKENING MOETEN ZIJN", id => $id)."\n")
		  if $acc_balres && !$balres;
		print {$fh} ("# ".__x("{id} ZOU EEN RESULTAATREKENING MOETEN ZIJN", id => $id)."\n")
		  if !$acc_balres && $balres;
	    }
	}
    }
}

sub dump_btw {
    my $fh = shift;
    print {$fh} ("\nBTW Tarieven\n\n");
    my $sth = $dbh->sql_exec("SELECT btw_id, btw_desc, btw_perc, btw_tariefgroep, btw_incl".
			     " FROM BTWTabel".
			     " ORDER BY btw_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc, $perc, $btg, $incl) = @$rr;
	my $extra = "";
	$extra .= " :tariefgroep=" . lc(BTWTARIEVEN->[$btg]);
	if ( $btg != BTWTARIEF_NUL ) {
	    $extra .= " :perc=".btwfmt($perc);
	    $extra .= " :" . qw(exclusief inclusief)[$incl] unless $incl;
	}
	my $t = sprintf(" %3d  %-20s  %s",
			$id, $desc, $extra);
	$t =~ s/\s+$//;
	print {$fh} ($t, "\n");
    }
}

sub dump_dbk {
    my $fh = shift;
    print {$fh} ("\nDagboeken\n\n");
    my $sth = $dbh->sql_exec("SELECT dbk_id, dbk_desc, dbk_type, dbk_dcsplit, dbk_acc_id".
			     " FROM Dagboeken".
			     " ORDER BY dbk_id");
    while ( my $rr = $sth->fetchrow_arrayref ) {
	my ($id, $desc, $type, $dc, $acc_id) = @$rr;
	$acc_id = 0 if $type == DBKTYPE_INKOOP  && $dbh->std_acc("crd", 0) == $acc_id;
	$acc_id = 0 if $type == DBKTYPE_VERKOOP && $dbh->std_acc("deb", 0) == $acc_id;
	my $t = sprintf("  %-4s  %-20s  :type=%-10s %s",
			$id, $desc, lc(DBKTYPES->[$type]),
			($acc_id ? ":rekening=$acc_id" : "").
			($dc ? " :dc" : ""),
		       );
	$t =~ s/\s+$//;
	print {$fh} ($t, "\n");
    }
}

################ API functions ################

sub new {
    bless \my $x, shift;
}

sub add_gbk {
    my ($self, @args) = @_;

    my $opts = pop(@args);	# currently unused
    my $in_transaction;
    my $anyfail;
    my $ret = "";

    while ( @args ) {
	my ($gbk, $flags, $desc, $vrd) = splice( @args, 0, 4 );
	if ( defined($flags) and defined($desc) and defined($vrd) ) {
	    my ( $balres, $debcrd, $kstomz, $fixed );
	    ( $flags, $fixed ) = ( $1, !!$2 ) if $flags =~ /^(.)(!)$/;
	    $flags = lc($flags);

	    my $t = $dbh->lookup($gbk, qw(Accounts acc_id acc_desc));
	    if ( $t ) {
		warn "?".
		  __x("Grootboekrekening {gbk} ({desc}) bestaat reeds",
		      gbk => $gbk, desc => $t)."\n";
		$anyfail++;
		next;
	    }
	    $balres = $dbh->lookup($vrd, qw(Verdichtingen vdi_id vdi_balres));
	    unless ( defined $balres ) {
		warn "?".__x("Onbekende verdichting: {vrd}",
			     vrd => $vrd)."\n";
		$anyfail++;
		next;
	    }
	    if ( $balres ) {
		if ( $flags =~ /^[dc]$/ ) {
		    $debcrd = $flags eq 'd';
		}
		else {
		    warn "?"._T("Ongeldig type voor balansrekening (alleen D / C toegestaan)")."\n";
		    $anyfail++;
		    next;
		}
	    }
	    else {
		if ( $flags =~ /^[kon]$/ ) {
		    $kstomz = $flags eq 'k' ? 1 : $flags eq 'o' ? 0 : undef;
		}
		else {
		    warn "?"._T("Ongeldig type voor resultaatrekening (alleen K / O / N toegestaan)")."\n";
		    $anyfail++;
		    next;
		}
	    }
	    $dbh->begin_work unless $in_transaction++;
	    $t = $dbh->sql_insert("Accounts",
				  [qw(acc_id acc_desc acc_struct acc_balres
				      acc_debcrd acc_dcfixed acc_kstomz
				      acc_btw acc_ibalance acc_balance)],
				  $gbk, $desc, $vrd,
				  $balres,
				  $debcrd,
				  $fixed,
				  $kstomz,
				  undef, 0, 0);
	    unless ( $t ) {
		warn "?".__x("Fout tijdens het opslaan van grootboekrekening {gbk}",
			     gbk => $gbk)."\n";
		$anyfail++;
		next;
	    }
	}

	unless ( $anyfail ) {
	    my $rr = $dbh->do("SELECT acc_desc, acc_balres, acc_debcrd,".
			      "       acc_kstomz, acc_dcfixed, vdi_id, vdi_desc, vdi_struct".
			      " FROM Accounts, Verdichtingen".
			      " WHERE acc_id = ?".
			      " AND acc_struct = vdi_id", $gbk);
	    unless ( $rr ) {
		warn "!".__x("Onbekende grootboekrekening: {gbk}",
			     gbk => $gbk)."\n";
		#$anyfail++;
		next;
	    }

	    my $t = $dbh->lookup($rr->[7], qw(Verdichtingen vdi_id vdi_desc));
	    $ret .=
	      __x("{balres} {gbk} {debcrd}{fixed}{kstomz} ({desc});".
		  " Verdichting {vrd} ({vdesc});".
		  " Hoofdverdichting {hvrd} ({hdesc})",
		  balres => ($rr->[1] ? "Balansrekening" : "Resultaatrekening"),
		  gbk => $gbk, desc => $rr->[0],
		  debcrd => ($rr->[1] ? ($rr->[2] ? "Debet" : "Credit") : ""),
		  kstomz => ($rr->[1] ? "" : defined($rr->[3]) ? $rr->[3] ? " Kosten" : " Omzet" : " Neutraal"),
		  fixed => $rr->[4] ? "!" : "",
		  vrd => $rr->[5], vdesc => $rr->[6],
		  hvrd => $rr->[7], hdesc => $t,
		 )."\n";
	}
    }

    if ( $in_transaction ) {
	$anyfail ? $dbh->rollback : $dbh->commit;
    }
    return $ret;
}

1;
