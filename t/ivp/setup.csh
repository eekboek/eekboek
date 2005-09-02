setenv EB_LIB ../blib/lib
setenv EB_DB_NAME eekboek_sample
if ( $?PERL5LIB ) then
    setenv PERL5LIB ${EB_LIB}:$PERL5LIB
else
    setenv PERL5LIB ${EB_LIB}
endif
set path = ( ../blib/script $path )

alias balans   "ebshell -c balans"
alias result   "ebshell -c result"
alias journaal "ebshell -c journaal"
alias rebuild "sh newdb.sh ; pg_dump -c $EB_DB_NAME > reset.sql"
