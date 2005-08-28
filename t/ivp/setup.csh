setenv EB_LIB ..
setenv EB_DB_NAME eekboek_sample
setenv EB_DB "dbi:Pg:dbname=${EB_DB_NAME}"
if ( $?PERL5LIB ) then
    setenv PERL5LIB ${EB_LIB}:$PERL5LIB
else
    setenv PERL5LIB ${EB_LIB}
endif

alias ebshell  "perl $EB_LIB/ebshell.pl"
alias balans   "perl $EB_LIB/ebshell.pl -c balans"
alias result   "perl $EB_LIB/ebshell.pl -c result"
alias journaal "perl $EB_LIB/ebshell.pl -c journaal"
alias rebuild "sh newdb.sh ; pg_dump -c $EB_DB_NAME > reset.sql"
