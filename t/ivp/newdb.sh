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
perl -Mlib=$EB_LIB $EB_LIB/schema.pl schema.dat || exit 

# Creeer een nieuwe database.
createdb ${EB_DB_NAME} || createdb --template=template0 ${EB_DB_NAME} || createdb ${EB_DB_NAME}

# Add proc lang
createlang plpgsql ${EB_DB_NAME}

# Vul de database met het schema.
psql ${EB_DB_NAME} < $EB_LIB/eekboek.sql

# Open de administratie.
# --btw-periode = 1 (jaar) of 4 (kwartaal)
perl -Mlib=$EB_LIB -w $EB_LIB/opening.pl \
    --admin="EekBoek Demo Administratie 2004" \
    --periode=2004 \
    --btw-periode=1 \
    --check=15854,77 \
    < open.dat

# Voeg de relaties toe.
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl < relaties.eb
