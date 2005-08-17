#!/bin/sh

. ./setup.sh

EB_SQL_NOW=2004-12-31; export EB_SQL_NOW

rm -f *.sql *.log

echo "=== $EB_DB_NAME === newdb ==="
rebuild > newdb.log 2>&1

echo "=== $EB_DB_NAME === mutaties ==="
ebshell --echo < mutaties.eb > mutaties.log 2>&1

echo "=== $EB_DB_NAME === verificatie ==="
ebshell -c balans | diff -c - balans.txt
ebshell -c balans --detail=0 | diff -c - balans0.txt
ebshell -c balans --detail=1 | diff -c - balans1.txt
ebshell -c balans --detail=2 | diff -c - balans2.txt
ebshell -c result | diff -c - result.txt
ebshell -c result --detail=0 | diff -c - result0.txt
ebshell -c result --detail=1 | diff -c - result1.txt
ebshell -c result --detail=2 | diff -c - result2.txt
ebshell -c journaal | diff -c - journaal.txt
ebshell -c journaal postbank | diff -c - journaal-postbank.txt
ebshell -c journaal postbank:24 | diff -c - journaal-postbank24.txt
ebshell -c journaal 48 | diff -c - journaal-48.txt
ebshell -c proefensaldibalans | diff -c - proef.txt
ebshell -c proefensaldibalans --detail=0 | diff -c - proef0.txt
ebshell -c proefensaldibalans --detail=1 | diff -c - proef1.txt
ebshell -c proefensaldibalans --detail=2 | diff -c - proef2.txt
ebshell -c grootboek | diff -c - grootboek.txt
ebshell -c grootboek --detail=0 | diff -c - grootboek0.txt
ebshell -c grootboek --detail=1 | diff -c - grootboek1.txt
ebshell -c grootboek --detail=2 | diff -c - grootboek2.txt
ebshell -c btwaangifte j | diff -c - btw.txt

if test -x /usr/local/bin/postgresql_autodoc
then
    echo "=== $EB_DB_NAME === autodoc ==="
    /usr/local/bin/postgresql_autodoc -d $EB_DB_NAME -t html
fi
