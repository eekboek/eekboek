#!/bin/sh

if [ -z "$EB_DB_NAME" ]
then
    echo "Error: EB_DB_NAME not set" 1>&2
    exit 1
fi

# Verwijder enige bestaande database voor deze administratie.
dropdb ${EB_DB_NAME}

# Creeer een nieuwe database.
createdb ${EB_DB_NAME} || createdb --template=template0 ${EB_DB_NAME} || createdb ${EB_DB_NAME}

# Add proc lang
createlang plpgsql ${EB_DB_NAME}

# Vul de database met het schema.
perl -Mlib=$EB_LIB $EB_LIB/EB/Globals.pm > constants.sql
perl -Mlib=$EB_LIB $EB_LIB/schema.pl schema.dat
psql ${EB_DB_NAME} < $EB_LIB/eekboek.sql

# Open de administratie.
perl -Mlib=$EB_LIB -w $EB_LIB/opening.pl \
    --admin="EekBoek Demo Administratie 2004" \
    --periode=2004 \
    --btw-periode=1 \
    --check=15854,77 \
    <<EOF
# Data voor openingsbalans:
230  1344.37
231  1304.81
240  13378.48
241  12106.78
1120 1131.92
500  2443.18
EOF

# Voeg de relaties toe.
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl <<EOF
# Crediteuren: relatie <code> "<omschrijving>" standaardrekening
relatie XS4ALL "XS4All Internet B.V." 4905
relatie KPN "KPN" 4900

# Debiteuren: relatie <code> "<omschrijving>" standaardrekening
relatie ACME "Acme Corp." 8000

# De laatste "3" geeft aan dat dit een relatie buiten Europa is.
# Dit is van belang voor de BTW.
# (Syntax wijzigt nog wel een keer)
relatie ORA "O'Reilly & Associates" 8100 3
EOF
