#!/bin/sh

. ./setup.sh

EBSHELL="ebshell -X -f ivp.conf"
EB_DB_NAME=eekboek_sample

rm -f *.sql *.log

echo "=== $EB_DB_NAME === newdb ==="
sh ./newdb.sh > newdb.log 2>&1 || exit 1
egrep '^(\?|ERROR)' newdb.log >/dev/null && exit 1

echo "=== $EB_DB_NAME === mutaties ==="
${EBSHELL} --echo < mutaties.eb > mutaties.log 2>&1
grep '^\?' mutaties.log >/dev/null && exit 1

echo "=== $EB_DB_NAME === verificatie ==="

# Verify: balans in varianten.
${EBSHELL} -c balans | diff -c - balans.txt
${EBSHELL} -c balans --detail=0 | diff -c - balans0.txt
${EBSHELL} -c balans --detail=1 | diff -c - balans1.txt
${EBSHELL} -c balans --detail=2 | diff -c - balans2.txt

# Verify: verlies/winst in varianten.
${EBSHELL} -c result | diff -c - result.txt
${EBSHELL} -c result --detail=0 | diff -c - result0.txt
${EBSHELL} -c result --detail=1 | diff -c - result1.txt
${EBSHELL} -c result --detail=2 | diff -c - result2.txt

# Verify: Journaal.
${EBSHELL} -c journaal | diff -c - journaal.txt
# Verify: Journaal van dagboek.
${EBSHELL} -c journaal postbank | diff -c - journaal-postbank.txt
# Verify: Journaal van boekstuk.
${EBSHELL} -c journaal postbank:24 | diff -c - journaal-postbank24.txt

# Verify: Proef- en Saldibalans in varianten.
${EBSHELL} -c proefensaldibalans | diff -c - proef.txt
${EBSHELL} -c proefensaldibalans --detail=0 | diff -c - proef0.txt
${EBSHELL} -c proefensaldibalans --detail=1 | diff -c - proef1.txt
${EBSHELL} -c proefensaldibalans --detail=2 | diff -c - proef2.txt

# Verify: Grootboek in varianten.
${EBSHELL} -c grootboek | diff -c - grootboek.txt
${EBSHELL} -c grootboek --detail=0 | diff -c - grootboek0.txt
${EBSHELL} -c grootboek --detail=1 | diff -c - grootboek1.txt
${EBSHELL} -c grootboek --detail=2 | diff -c - grootboek2.txt

# Verify: BTW aangifte.
${EBSHELL} -c btwaangifte j | diff -c - btw.txt

# Verify: HTML generatie.
${EBSHELL} -c balans --detail=2 --gen-html | diff -c - balans2.html
${EBSHELL} -c balans --detail=2 --gen-html --style=xxx | diff -c - balans2xxx.html

# Verify: CSV generatie.
${EBSHELL} -c balans --detail=2 --gen-csv | diff -c - balans2.csv

# Aanmaken HTML documentatie van database schema (optioneel).
if test -x /usr/local/bin/postgresql_autodoc
then
    echo "=== $EB_DB_NAME === autodoc ==="
    /usr/local/bin/postgresql_autodoc -d $EB_DB_NAME -t html
fi
