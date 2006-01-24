#!/bin/sh

: ${EBSHELL:=ebshell -X -f ivp.conf}

# Creeer een nieuwe database en vul de database met het schema.
$EBSHELL --createdb --schema=sample -c || exit 1

# Voeg de relaties toe.
$EBSHELL --echo < relaties.eb

# Vul de database met openingsgegevens, evt. openstaande posten, en open.
$EBSHELL --echo < opening.eb

# Aanmaken restore set.
pg_dump -c eekboek_sample > reset.sql

