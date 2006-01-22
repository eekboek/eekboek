#!/bin/sh

: ${EBSHELL:=ebshell -X -f ivp.conf}

# Verwijder enige bestaande database voor deze administratie.
dropdb ${EB_DB_NAME}

# Creeer een nieuwe database en vul de database met het schema.
$EBSHELL --createdb --schema=sample -c || exit 1

# Voeg de relaties toe.
$EBSHELL --echo < relaties.eb

# Vul de database met openingsgegevens, evt. openstaande posten, en open.
$EBSHELL --echo < opening.eb

# Aanmaken restore set.
pg_dump -c $EB_DB_NAME > reset.sql

