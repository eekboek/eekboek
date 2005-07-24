setenv EB_LIB ..
setenv EB_DB_NAME sample
setenv EB_DB "dbi:Pg:dbname=${EB_DB_NAME}"
setenv PERL5LIB ${EB_LIB}:$PERL5LIB

alias ebshell  "perl $EB_LIB/ebshell.pl"
alias balans   "perl $EB_LIB/ebshell.pl -c balans"
alias result   "perl $EB_LIB/ebshell.pl -c result"
alias journaal "perl $EB_LIB/ebshell.pl -c journaal"
alias rebuild "sh newdb.sh ; sh $EB_LIB/relaties.sh ; sh $EB_LIB/opening.sh ; pg_dump -c $EB_DB_NAME > reset.sql"
