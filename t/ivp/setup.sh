EB_LIB=../blib/lib
EB_DB_NAME=eekboek_sample
if [ -z "$PERL5LIB" ]
then
    PERL5LIB=${EB_LIB}
else
    PERL5LIB=${EB_LIB}:$PERL5LIB
fi
PATH=../blib/script:$PATH

export EB_LIB EB_DB_NAME EB_DB PERL5LIB PATH

rebuild() {
    sh newdb.sh
    pg_dump -c $EB_DB_NAME > reset.sql
}

