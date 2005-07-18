#!/bin/sh

mut=mutaties.eb
perl -Mlib=$EB_LIB -w $EB_LIB/eximut.pl > $mut
if [ -s mutaties-fixed.eb ]; then
    mut=mutaties-fixed.eb
    echo "Overriding mutaties.eb with $mut" 1>&2
fi
perl -Mlib=$EB_LIB -w $EB_LIB/ebshell.pl --echo < $mut 2>&1
