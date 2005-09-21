# The modules.
EB_LIB=../blib/lib ; export EB_LIB

# Name of the database.
EB_DB_NAME=eekboek_sample ; export EB_DB_NAME

# Fake current date (to compare reports).
EB_SQL_NOW=2004-12-31 ; export EB_SQL_NOW

# Language selection.
EB_LANG=nl_NL ; export EB_LANG

# Prepend EB lib to Perl PATH
if [ -z "$PERL5LIB" ]
then
    PERL5LIB=${EB_LIB}
else
    PERL5LIB=${EB_LIB}:$PERL5LIB
fi

# Append official scripts dir to PATH
PATH=../blib/script:$PATH

export PERL5LIB PATH

rebuild() {
    sh newdb.sh
    pg_dump -c $EB_DB_NAME > reset.sql
}

