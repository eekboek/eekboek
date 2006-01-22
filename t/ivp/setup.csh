#!/bin/csh

set EB_DB_NAME = eekboek_sample

if ( -f ../blib/lib/EB.pm ) then
    set EB_LIB=../blib/lib
    set EB_PATH=../blib/script
    echo "Using blib version"
else if ( -f ../lib/EB.pm ) then
    set EB_LIB=../lib
    set EB_PATH=../scripts
    echo "Using development version"
else
    echo "Using installed version"
endif

# Prepend EB lib to Perl PATH
if ( $?EB_LIB ) then
    if ( ! $?PERL5LIB ) then
	setenv PERL5LIB ${EB_LIB}
    else
	setenv PERL5LIB ${EB_LIB}:${PERL5LIB}
    endif
endif

# Append official scripts dir to PATH
if ( $?EB_PATH ) then
    setenv PATH ${EB_PATH}:${PATH}
endif

# Some handy aliases.
alias balans   "ebshell -c balans"
alias result   "ebshell -c result"
alias journaal "ebshell -c journaal"
alias rebuild "sh newdb.sh ; pg_dump -c $EB_DB_NAME > reset.sql"
