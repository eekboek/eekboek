EB_LIB=..
EB_DB_NAME=eekboek_sample
EB_DB="dbi:Pg:dbname=${EB_DB_NAME}"
if [ -z "$PERL5LIB" ]
then
    PERL5LIB=${EB_LIB}
else
    PERL5LIB=${EB_LIB}:$PERL5LIB
fi

export EB_LIB EB_DB_NAME EB_DB PERL5LIB

ebshell() {
    perl $EB_LIB/ebshell.pl ${1+"$@"}
}

rebuild() {
    sh newdb.sh
    pg_dump -c $EB_DB_NAME > reset.sql
}

