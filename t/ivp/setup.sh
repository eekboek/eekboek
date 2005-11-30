# Name of the database.
if [ -z "$EB_DB_NAME" ]
then
    EB_DB_NAME=eekboek_sample
fi
export EB_DB_NAME

# Language selection.
if [ -z "$EB_LANG" ]
then
    EB_LANG=nl_NL
fi
export EB_LANG

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

# Prepend EB lib to Perl PATH
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

rebuild() {
    sh newdb.sh
    pg_dump -c $EB_DB_NAME > reset.sql
}

