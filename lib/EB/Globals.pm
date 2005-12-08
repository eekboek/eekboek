#!/usr/bin/perl

package EB::Globals;

use strict;

use base qw(Exporter);

our @EXPORT;

sub _newconst($$) {
    my $t = $_[1];
    $t = "'$t'" unless $t =~ /^\d+$/ || $t =~ /^\[.*\]$/;
    eval("sub $_[0](){$t}");
    push(@EXPORT, $_[0]);
}

sub N__($) { $_[0] }

BEGIN {
    _newconst("SCM_MAJVERSION", 1);
    _newconst("SCM_MINVERSION", 0);
    _newconst("SCM_REVISION", 5);

    _newconst("AMTPRECISION", 2);
    _newconst("AMTWIDTH", 9);
    _newconst("BTWPRECISION", 4);
    _newconst("BTWWIDTH", 5);
    _newconst("AMTSCALE", 100);
    _newconst("BTWSCALE", 10000);

    _newconst("BKY_PREVIOUS", "<<<<");

    my $i = 1;
    map { _newconst("DBKTYPE_$_", $i++) }
      qw(INKOOP VERKOOP BANK KAS MEMORIAAL);
    _newconst("DBKTYPES",
	      "[qw(".N__("-- Inkoop Verkoop Bank Kas Memoriaal").")]");
    $i = 0;
    map { _newconst("BTWTYPE_$_", $i++) }
      qw(GEEN HOOG LAAG);
    _newconst("BTWTYPES", "[qw(".N__("Geen Hoog Laag").")]");
    _newconst("BTWPER_GEEN", 0);
    _newconst("BTWPER_JAAR", 1);
    _newconst("BTWPER_KWARTAAL", 4);
    _newconst("BTWPER_MAAND", 12);

    $i = 0;
    map { _newconst("BTW_$_", $i++) }
      qw(NORMAAL VERLEGD INTRA EXTRA);

}

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
