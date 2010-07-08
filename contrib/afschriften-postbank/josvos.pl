#!/usr/bin/perl
# 
# Ik heb een Perl-script gemaakt (een gestripte versie - qua lijst namen
#  etc. ) om de gedownloade Postbank data om te zetten
#  in boekstukregels voor de bankafschriften. 
# De output editten (start van bankafschrift boekstukken tussenvoegen,
#  soms de beschrijving editten -- xxx vervangen door de maand etc. --,
#  backslash van de laatste boekstukregel weghalen, etc.)
#  en het bespaart een hoop moeite.
# 
# De volgende disclaimers bij dit script:-):
# 
# - Het is een quick-and-very-dirty gehacked script, dat voor mij nu
#   even genoeg doet.
# 
# - Het is (dus) geen voorbeeld van een "mooi" en/of generiek programma
#   (globale variabelen, hardcoded waarden, etc., eigenlijk alles waar ik
#   normaal gesproken streng op tegen ben, zitten erin ;-)).
# 
# - Match op rekening doe ik nu nergens, maar is wellicht betrouwbaarder
#   ($tegenrek =~ /^123456789$/).
# 
# - Bij/af checks kan in een aantal gevallen weg (maar ik heb ook relaties
#   die zowel crediteur als debiteur zijn...), om het ontvangen/betalen
#   van creditfacturen vanzelf mee te nemen.
# 
# Gebruik de "jjjjmmdd" CSV download van de postbank als input en voer
# de "sort" output hiervan aan dit script.
# 
# Have fun,
# 
# --
# -- Jos Vos <jos@xos.nl>
# -- X/OS Experts in Open Systems BV
# 

sub af() {
	return ($afbij eq "Af");
}

sub bij() {
	return ($afbij eq "Bij");
}

sub crd() {
	$min = &af() ? "-" : "";
	print "\tcrd $ebdatum $_[0] ${min}$ebbedrag \\\n";
}

sub deb() {
	$min = &af() ? "-" : "";
	print "\tdeb $ebdatum $_[0] ${min}$ebbedrag \\\n";
}

sub std() {
	$min = &af() ? "-" : "";
	print "\tstd $ebdatum \"$_[0]\" ${min}$ebbedrag $_[1] \\\n";
}

while (<ARGV>) {
	chop();
	chop();

	($dummy, $datum, $naam, $rek, $tegenrek, $code, $afbij, $bedrag,
		$soort, $omschr, $dummy) = split('","', "\",${_},\"");
	next if ($datum eq 'Datum');

	($y, $m, $d) = $datum =~ /(....)(..)(..)/;
	$ebdatum = "${y}-${m}-${d}";
	$bedrag =~ s/,/./;
	$ebbedrag = $bedrag;


	if ($naam =~ /ALBERT HEIJN/ and &af()) {
		&crd("AH");

	} elsif ($naam =~ /^Centraal Beheer/ and &af()) {
		&crd("CB");

	} elsif ($naam =~ /^FORTIS ASR/ and &af()) {
		&crd("FORTIS");

	} elsif ($omschr =~ /FORTIS ASR/ and &bij()) {
		&crd("FORTIS");

	} elsif ($naam =~ /MAKRO A'DAM/ and &af()) {
		&crd("MAKRO");


	} elsif ($omschr =~ /^XXX BV/ and &bij()) {
		&deb("DEB_XXX");

	} elsif ($omschr =~ /^YYY NV/ and &bij()) {
		&deb("DEB_YYY");


	} elsif ($naam =~ /^VAN RENTE REKENING/ and &bij()) {
		&std("Van inbedrijf", "1192");

	} elsif ($naam =~ /^NAAR INBEDRIJFREKENING/ and &af()) {
		&std("Naar inbedrijf", "1192");

	} elsif ($naam =~ /X Y Onbekend/i and &af()) {
		&std("Salaris XY xxx 2007", "1944");

	} elsif ($omschr =~ /BELASTINGDIENST .* \d{3}3374206/ and &af()) {
		&std("LH xxx 07", "1710");

	} elsif ($naam =~ /BIJDRAGE GIROPAS/ and &af()) {
		&std("Kosten bankpas", "4980");

	} elsif ($naam =~ /^RC AFREKENING BETALINGSVERKEER/ and &af()) {
		&std("Bankkosten", "4980");


	} else {
		&std("??????????", "2000");
	}
}
