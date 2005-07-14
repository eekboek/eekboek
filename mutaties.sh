#!/bin/sh

perl -Mlib=$EB_LIB -w $EB_LIB/eximut.pl | tee mutaties.eb |
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl --echo
