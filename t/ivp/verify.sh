#!/bin/sh

. ./setup.sh

# Fake current date (to compare reports).
EB_SQL_NOW=2004-12-31 ; export EB_SQL_NOW

rm -f *.sql *.log

echo "=== $EB_DB_NAME === newdb ==="
sh ./newdb.sh > newdb.log 2>&1 || exit 1
egrep '^(\?|ERROR)' newdb.log >/dev/null && exit 1

echo "=== $EB_DB_NAME === mutaties ==="
ebshell --echo < mutaties.eb > mutaties.log 2>&1
grep '^\?' mutaties.log >/dev/null && exit 1

echo "=== $EB_DB_NAME === verificatie ==="

# Verify: balans in varianten.
ebshell -c balans | diff -c - balans.txt
ebshell -c balans --detail=0 | diff -c - balans0.txt
ebshell -c balans --detail=1 | diff -c - balans1.txt
ebshell -c balans --detail=2 | diff -c - balans2.txt

# Verify: verlies/winst in varianten.
ebshell -c result | diff -c - result.txt
ebshell -c result --detail=0 | diff -c - result0.txt
ebshell -c result --detail=1 | diff -c - result1.txt
ebshell -c result --detail=2 | diff -c - result2.txt

# Verify: Journaal.
ebshell -c journaal | diff -c - journaal.txt
# Verify: Journaal van dagboek.
ebshell -c journaal postbank | diff -c - journaal-postbank.txt
# Verify: Journaal van boekstuk.
ebshell -c journaal postbank:24 | diff -c - journaal-postbank24.txt

# Verify: Proef- en Saldibalans in varianten.
ebshell -c proefensaldibalans | diff -c - proef.txt
ebshell -c proefensaldibalans --detail=0 | diff -c - proef0.txt
ebshell -c proefensaldibalans --detail=1 | diff -c - proef1.txt
ebshell -c proefensaldibalans --detail=2 | diff -c - proef2.txt

# Verify: Grootboek in varianten.
ebshell -c grootboek | diff -c - grootboek.txt
ebshell -c grootboek --detail=0 | diff -c - grootboek0.txt
ebshell -c grootboek --detail=1 | diff -c - grootboek1.txt
ebshell -c grootboek --detail=2 | diff -c - grootboek2.txt

# Verify: BTW aangifte.
ebshell -c btwaangifte j | diff -c - btw.txt

# Verify: HTML generatie.
ebshell -c balans --detail=2 --gen-html | diff -c - balans2.html
ebshell -c balans --detail=2 --gen-html --style=xxx | diff -c - balans2xxx.html

# Verify: CSV generatie.
ebshell -c balans --detail=2 --gen-csv | diff -c - balans2.csv

# Aanmaken HTML documentatie van database schema (optioneel).
if test -x /usr/local/bin/postgresql_autodoc
then
    echo "=== $EB_DB_NAME === autodoc ==="
    /usr/local/bin/postgresql_autodoc -d $EB_DB_NAME -t html
fi
