#!/usr/bin/perl

package EB::Globals;

use strict;

use base qw(Exporter);

our @EXPORT;

sub _newconst($$) {
    eval("sub $_[0](){$_[1]}");
    push(@EXPORT, $_[0]);
}

BEGIN {
    _newconst("SCM_MAJVERSION", 1);
    _newconst("SCM_MINVERSION", 0);
    _newconst("SCM_REVISION", 0);

    _newconst("AMTPRECISION", 2);
    _newconst("AMTWIDTH", 9);
    _newconst("BTWPRECISION", 4);
    _newconst("BTWWIDTH", 5);
    _newconst("AMTSCALE", 100);
    _newconst("BTWSCALE", 10000);

    my $i = 1;
    map { _newconst("DBKTYPE_$_", $i++) }
      qw(INKOOP VERKOOP BANK KAS MEMORIAAL);
    _newconst("DBKTYPES",
	      "[qw(-- Inkoop Verkoop Bank Kas Memoriaal)]");
    $i = 1;
    map { _newconst("BTWTYPE_$_", $i++) }
      qw(HOOG LAAG GEEN);
    $i = 0;
    map { _newconst("BTWPER_$_", $i++) }
      qw(GEEN JAAR HALFJAAR TRIMESTER KWARTAAL);
}

unless ( caller ) {
    print STDOUT ("-- Constants\n\n",
		  "CREATE TABLE Constants (\n",
		  "    name\ttext not null primary key,\n",
		  "    value\tint\n",
		  ");\n\n",
		  "COMMENT ON TABLE Constants IS\n",
		  "  'This is generated from ", __PACKAGE__, ". DO NOT CHANGE.';\n\n",
		  "COPY Constants (name, value) FROM stdin;\n");

    foreach my $key ( sort(@EXPORT) ) {
	no strict;
	next if $key eq "DBKTYPES";
	print STDOUT ("$key\t", $key->(), "\n");
    }
    print STDOUT ("\\.\n");
}

1;
