#! make -f

# The bootstrap procedure must be executed ONCE after a fresh checkout
# of the development sources from git.

default :
	@echo "Use the 'bootstrap' target if you know what you are doing." 1>&2
	@test -f META.yml && echo "However, it looks as if this has been done already." 1>&1
	@test -f META.yml && echo "Please double check before proceeding." 1>&1

.NOTPARALLEL :			# all serial

################ Bootstrap ################

bootstrap : version examples dummies

version :
	perl check-version.pl

examples :
	$(foreach l,nl,${MAKE} -C lib/EB/examples/$l install;)

# Dummies are files that are (re)created by running perl Build.PL.
# However, they are required by the MANIFEST so there should be
# something there already.

dummies :
	echo '---' >META.yml
	echo '' > EekBoek.spec
	echo '' > t/ivp/ref/export.xaf

################ Release ################

release : verify_bootstrapped verify_releasable docs
	perl Build.PL
	./Build
	./Build test
	./Build dist

verify_bootstrapped :
	@if ! test -f META.yml; then \
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

