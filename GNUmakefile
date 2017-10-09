#! make -f

# The bootstrap procedure must be executed ONCE after a fresh checkout
# of the development sources from git.

BSTF = t/ivp/ref/export.xaf

default :
	@echo "Use the 'bootstrap' target if you know what you are doing." 1>&2
	@test -f ${BSTF} && echo "However, it looks as if this has been done already." 1>&1
	@test -f ${BSTF} && echo "Please double check before proceeding." 1>&1

.NOTPARALLEL :			# all serial

################ Pass-through ################

.PHONY : all
all :	Makefile cleanup
	mv Makefile.old Makefile
	$(MAKE) -f Makefile all

.PHONY : test
test : Makefile
	$(MAKE) -f Makefile test

.PHONY : clean
clean : cleanup
	rm -f *~

.PHONY : cleanup
cleanup : Makefile
	$(MAKE) -f Makefile clean

.PHONY : dist
dist : Makefile
	$(MAKE) -f Makefile dist

.PHONY : install
install : Makefile
	$(MAKE) -f Makefile install

Makefile : Makefile.PL lib/EB/Version.pm
	perl Makefile.PL

################ Bootstrap ################

bootstrap : examples dummies

version :
	perl check-version.pl

examples :
	cp lib/EB/examples/eekboek.conf lib/EB/res/templates/sample.conf
	$(foreach l,nl,${MAKE} -C lib/EB/examples/$l install;)

# Dummies are files that are (re)created by running perl Build.PL.
# However, they are required by the MANIFEST so there should be
# something there already.

dummies :
	echo '' >${BSTF}

################ Release ################

release : version verify_bootstrapped verify_releasable docs
	perl Makefile.PL
	${MAKE} -f Makefile all
	${MAKE} -f Makefile test
	${MAKE} -f Makefile dist

verify_bootstrapped :
	@if ! test -f ${BSTF}; then \
	  echo ""; echo ">>>> OOPS <<<<"; echo ""; \
	  echo "I have reason to believe you" "haven't" run '"make bootstrap"' yet.; \
	  echo ""; \
	  exit 1; \
	fi

verify_releasable :
	@if grep -q ".-" lib/EB/Version.pm; then \
	  echo ""; echo ">>>> OOPS <<<<"; echo ""; \
	  echo "This doesn't look releasable yet."; \
	  echo ""; \
	  exit 1; \
	fi

# Update the docs from the doc git, if possible.

docs :
	if test -f ../doc/GNUmakefile; then \
	  ( cd ../doc; \
	    ${MAKE} all install VERSION="`perl ../src/lib/EB/Version.pm`" ) \
	fi

################ Packaging ################

PERL := perl
PROJECT := EekBoek
TMP_DST := ${HOME}/tmp/${PROJECT}

to_tmp :
	rsync -avH --files-from=MANIFEST    ./ ${TMP_DST}/
	cp script/ebshell.pl script/ebwxshell.pl ${TMP_DST}/pp/
	${PERL} -pi -e 's;# (use App::Packager);$$1;' ${TMP_DST}/pp/eb*shell.pl

to_tmp_cpan :
	test -d ${TMP_DST}/CPAN || mkdir ${TMP_DST}/CPAN
	rsync -avH lib/EB/CPAN/App/ ${TMP_DST}/CPAN/App
