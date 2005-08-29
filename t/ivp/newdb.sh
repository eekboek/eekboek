#!/bin/sh

if [ -z "$EB_DB_NAME" ]
then
    echo "Error: EB_DB_NAME not set" 1>&2
    exit 1
fi

# Verwijder enige bestaande database voor deze administratie.
dropdb ${EB_DB_NAME}

# Creeer de schema files.
perl -Mlib=$EB_LIB $EB_LIB/EB/Globals.pm > constants.sql
perl -Mlib=$EB_LIB -MEB::Tools::Schema -e load -- schema.dat || exit 

# Creeer een nieuwe database. The || are for fallback if a template is
# temporary in use.
createdb -E latin1 ${EB_DB_NAME} ||
 createdb --template=template0 -E latin1 ${EB_DB_NAME} ||
  createdb -E latin1 ${EB_DB_NAME}

# Vul de database met het schema.
psql ${EB_DB_NAME} < $EB_LIB/eekboek.sql

pg_dump -c $EB_DB_NAME > reset.sql

# Open de administratie.
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl --echo < opening.eb

# Voeg de relaties toe.
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl --echo < relaties.eb
