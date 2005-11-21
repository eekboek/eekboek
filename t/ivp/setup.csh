# The modules.
setenv EB_LIB ../blib/lib

# Name of the database.
setenv EB_DB_NAME eekboek_sample

# Fake current date (to compare reports).
setenv EB_SQL_NOW 2004-12-31

# Language selection.
setenv EB_LANG nl_NL

# Prepend EB lib to Perl PATH
setenv PERL5LIB ${EB_LIB}:$PERL5LIB

# Append official scripts dir to PATH
set path = ( ../blib/script $path )

# Some handy aliases.
alias balans   "ebshell -c balans"
alias result   "ebshell -c result"
alias journaal "ebshell -c journaal"
alias rebuild "sh newdb.sh ; sh $EB_LIB/relaties.sh ; sh $EB_LIB/opening.sh ; pg_dump -c $EB_DB_NAME > reset.sql"
