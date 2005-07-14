#!/bin/sh

# Migreren relaties.

# In praktijk is het natuurlijk beter de migratie uit te voeren naar
# een bestand, en dit bestand aan te vullen met correcte
# rekeningnummers.

perl $EB_LIB/exirel.pl | perl -Mlib=$EB_LIB $EB_LIB/ebshell.pl --echo

