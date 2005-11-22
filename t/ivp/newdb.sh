#!/bin/sh

if [ -z "$EB_DB_NAME" ]
then
    echo "Error: EB_DB_NAME not set" 1>&2
    exit 1
fi

: ${EBSHELL:=ebshell}

# Verwijder enige bestaande database voor deze administratie.
dropdb ${EB_DB_NAME}

# Creeer een nieuwe database. The || are for fallback if a template is
# temporary in use.
createdb -E latin1 ${EB_DB_NAME} ||
 createdb --template=template0 -E latin1 ${EB_DB_NAME} ||
  createdb -E latin1 ${EB_DB_NAME}

# Vul de database met het schema.
$EBSHELL --schema=sample -c || exit 1

# Voeg de relaties toe.
$EBSHELL --echo < relaties.eb

# Vul de database met openingsgegevens, evt. openstaande posten, en open.
$EBSHELL --echo < opening.eb

# Aanmaken restore set.
pg_dump -c $EB_DB_NAME > reset.sql

