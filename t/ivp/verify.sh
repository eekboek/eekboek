csh <<'EOF'
source setup.csh
echo "=== $EB_DB_NAME === newdb ==="
sh ./newdb.sh >& newdb.log
echo "=== $EB_DB_NAME === mutaties ==="
perl -I$EB_LIB $EB_LIB/ebshell.pl --echo < mutaties.eb >& mutaties.log
echo "=== $EB_DB_NAME === verificatie ==="
perl -I$EB_LIB $EB_LIB/ebshell.pl -c balans | diff -c - balans.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c balans --detail=0 | diff -c - balans0.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c balans --detail=1 | diff -c - balans1.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c balans --detail=2 | diff -c - balans2.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c result | diff -c - result.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c result --detail=0 | diff -c - result0.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c result --detail=1 | diff -c - result1.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c result --detail=2 | diff -c - result2.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c journaal | diff -c - journaal.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c journaal postbank | diff -c - journaal-postbank.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c journaal postbank:24 | diff -c - journaal-postbank24.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c journaal 48 | diff -c - journaal-48.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c proefensaldibalans | diff -c - proef.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c proefensaldibalans --detail=0 | diff -c - proef0.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c proefensaldibalans --detail=1 | diff -c - proef1.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c proefensaldibalans --detail=2 | diff -c - proef2.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c grootboek | diff -c - grootboek.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c grootboek --detail=0 | diff -c - grootboek0.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c grootboek --detail=1 | diff -c - grootboek1.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c grootboek --detail=2 | diff -c - grootboek2.txt
perl -I$EB_LIB $EB_LIB/ebshell.pl -c btwaangifte j | diff -c - btw.txt
EOF
