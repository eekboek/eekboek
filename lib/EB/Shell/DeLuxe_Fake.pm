#! perl --			-*- coding: utf-8 -*-

use utf8;

my $pre;
my $t;

use EB;

sub foo {
    warn("?"._T("Vervolgregel ontbreekt in de invoer.")."\n") if $pre;
    die("?"._T("Invoer moet Unicode (UTF-8) zijn.")."\n");
    warn("?".__x("Geen geldige UTF-8 tekens in regel {line} van de invoer",
		 line => $.)."\n".$t."\n");
    warn("!".__x("Invoerregel {lno} bevat onzichtbare tekens na de backslash",
		 lno => $.)."\n") # can't happen?
}

1;
