#!/usr/bin/perl

package EB::Globals;

use strict;

use base qw(Exporter);

our @EXPORT;

sub _newconst($$) {
    my $t = $_[1];
    $t = "'$t'" unless $t =~ /^\d+$/ || $t =~ /^\[.*\]$/;
    #warn("sub $_[0](){$t}\n");
    eval("sub $_[0](){$t}");
    push(@EXPORT, $_[0]);
}

sub N__($) { $_[0] }

BEGIN {
    _newconst("SCM_MAJVERSION", 1);
    _newconst("SCM_MINVERSION", 0);
    _newconst("SCM_REVISION",  10);

    _newconst("AMTPRECISION",   2);
    _newconst("AMTWIDTH",       9);
    _newconst("BTWPRECISION",   4);
    _newconst("BTWWIDTH",       5);
    _newconst("AMTSCALE",     100);
    _newconst("BTWSCALE",   10000);

    _newconst("BKY_PREVIOUS", "<<<<");

    my $i = 1;
    map { _newconst("DBKTYPE_$_", $i++) }
      qw(INKOOP VERKOOP BANK KAS MEMORIAAL);
    _newconst("DBKTYPES",
	      "[qw(".N__("-- Inkoop Verkoop Bank Kas Memoriaal").")]");
    $i = 0;
    map { _newconst("BTWTARIEF_$_", $i++) }
      qw(NUL HOOG LAAG);
    _newconst("BTWTARIEVEN", "[qw(".N__("Nul Hoog Laag").")]");
    _newconst("BTWPER_GEEN", 0);
    _newconst("BTWPER_JAAR", 1);
    _newconst("BTWPER_KWARTAAL", 4);
    _newconst("BTWPER_MAAND", 12);

    $i = 0;
    map { _newconst("BTWTYPE_$_", $i++) }
      qw(NORMAAL VERLEGD INTRA EXTRA);
    _newconst("BTWTYPES", "[qw(".N__("Normaal Verlegd Intra Extra").")]");

    _newconst("BTWKLASSE_BTW_BIT",   0x200);
    _newconst("BTWKLASSE_KO_BIT",    0x100);
    _newconst("BTWKLASSE_TYPE_BITS", 0x0ff);

}

sub BTWKLASSE($$;$) {
    unshift(@_, 1) if @_ == 2;
    ($_[0] ? BTWKLASSE_BTW_BIT : 0)
      | ($_[1] & BTWKLASSE_TYPE_BITS)
	| ($_[2] ? BTWKLASSE_KO_BIT : 0);
}

BEGIN { push(@EXPORT, qw(BTWKLASSE)) }

unless ( caller ) {
    print STDOUT ("-- Constants\n\n",
		  "COMMENT ON TABLE Constants IS\n",
		  "  'This is generated from ", __PACKAGE__, ". DO NOT CHANGE.';\n\n",
		  "COPY Constants (name, value) FROM stdin;\n");

    foreach my $key ( sort(@EXPORT) ) {
	no strict;
	next if ref($key->());
	print STDOUT ("$key\t", $key->(), "\n");
    }
    print STDOUT ("\\.\n");
}

1;
