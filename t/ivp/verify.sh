#!/bin/sh

# Find library.
if test -f ../blib/lib/EB.pm
then
    EB_LIB=../blib/lib
    EB_PATH=../blib/script
    echo "Using blib version"
elif test -f ../lib/EB.pm
then
    EB_LIB=../lib
    EB_PATH=../scripts
    echo "Using development version"
else
    echo "Using installed version"
fi

# Prepend EB lib to Perl PATH.
if [ -n "$EB_LIB" ]
then
    if [ -z "$PERL5LIB" ]
    then
	PERL5LIB=${EB_LIB}
    else
	PERL5LIB=${EB_LIB}:$PERL5LIB
    fi
fi
export PERL5LIB

# Append official scripts dir to PATH
if [ -n "$EB_PATH" ]
then
    PATH=$EB_PATH:$PATH
fi
export PATH

# ebshell command. Only use the supplied ivp.conf.
EBSHELL="ebshell -X -f ivp.conf"

rm -f *.sql *.log *.html

echo "=== IVP === aanmaken database ==="
# Creeer een nieuwe database en vul de database met het schema.
${EBSHELL} --createdb --schema=sample -c  > createdb.log 2>&1 || exit 1
egrep '^(\?|ERROR)' createdb.log >/dev/null && exit 1

echo "=== IVP === relaties ==="
# Voeg de relaties toe.
${EBSHELL} --echo < relaties.eb > relaties.log 2>&1
egrep '^(\?|ERROR)' relaties.log >/dev/null && exit 1

echo "=== IVP === openen administratie ==="
# Vul de database met openingsgegevens, evt. openstaande posten, en open.
${EBSHELL} --echo < opening.eb > opening.log 2>&1
egrep '^(\?|ERROR)' relaties.log >/dev/null && exit 1

echo "=== IVP === mutaties ==="
${EBSHELL} --echo < mutaties.eb > mutaties.log 2>&1
grep '^\?' mutaties.log >/dev/null && exit 1

echo "=== IVP === verificatie ==="

# Verify: balans in varianten.
${EBSHELL} -c balans            | diff -c - ref/balans.txt
${EBSHELL} -c balans --detail=0 | diff -c - ref/balans0.txt
${EBSHELL} -c balans --detail=1 | diff -c - ref/balans1.txt
${EBSHELL} -c balans --detail=2 | diff -c - ref/balans2.txt
${EBSHELL} -c balans --verdicht | diff -c - ref/balans2.txt

# Verify: verlies/winst in varianten.
${EBSHELL} -c result            | diff -c - ref/result.txt
${EBSHELL} -c result --detail=0 | diff -c - ref/result0.txt
${EBSHELL} -c result --detail=1 | diff -c - ref/result1.txt
${EBSHELL} -c result --verdicht | diff -c - ref/result2.txt

# Verify: Journaal.
${EBSHELL} -c journaal             | diff -c - ref/journaal.txt
# Verify: Journaal van dagboek.
${EBSHELL} -c journaal postbank    | diff -c - ref/journaal-postbank.txt
# Verify: Journaal van boekstuk.
${EBSHELL} -c journaal postbank:24 | diff -c - ref/journaal-postbank24.txt

# Verify: Proef- en Saldibalans in varianten.
${EBSHELL} -c proefensaldibalans            | diff -c - ref/proef.txt
${EBSHELL} -c proefensaldibalans --detail=0 | diff -c - ref/proef0.txt
${EBSHELL} -c proefensaldibalans --detail=1 | diff -c - ref/proef1.txt
${EBSHELL} -c proefensaldibalans --detail=2 | diff -c - ref/proef2.txt
${EBSHELL} -c proefensaldibalans --verdicht | diff -c - ref/proef2.txt

# Verify: Grootboek in varianten.
${EBSHELL} -c grootboek            | diff -c - ref/grootboek.txt
${EBSHELL} -c grootboek --detail=0 | diff -c - ref/grootboek0.txt
${EBSHELL} -c grootboek --detail=1 | diff -c - ref/grootboek1.txt
${EBSHELL} -c grootboek --detail=2 | diff -c - ref/grootboek2.txt

# Verify: BTW aangifte.
${EBSHELL} -c btwaangifte j | diff -c - ref/btw.txt

# Verify: HTML generatie.
${EBSHELL} -c balans --detail=2 --gen-html             | diff -c - ref/balans2.html
${EBSHELL} -c balans --detail=2 --gen-html --style=xxx | diff -c - ref/balans2xxx.html

# Verify: CSV generatie.
${EBSHELL} -c balans --detail=2 --gen-csv | diff -c - ref/balans2.csv

echo "=== IVP === gereed ==="
