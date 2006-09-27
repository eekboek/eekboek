#!/bin/sh

: ${EB_SHELL:=ebshell}

EB_DB=`${EB_SHELL} --printcfg database:fullname`

# Vul de database met het schema, eventuele openstaande posten de
# de bijbehorende relaties, en open.
cat relaties.eb opening.eb | ${EB_SHELL} --createdb --schema=schema

# Aanmaken restore set.
pg_dump -c ${EB_DB} > reset.sql

