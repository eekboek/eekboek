#! make -f

# This procedure must be executed ONCE after e fresh checkout of
# the development sources.

default :
	@echo "Use the 'bootstrap' target if you know what you are doing." 1>&2
	@test -f META.yml && echo "However, it looks as if this has been done already." 1>&1
	@test -f META.yml && echo "Please double check before proceeding." 1>&1

.NOTPARALLEL :			# all serial

bootstrap : version schemas dummies

release : bootstrap docs
	perl Build.PL
	./Build
	./Build test
	./Build dist

version :
	perl git-version.pl

# Generate lib/EB/res/templates/nl/foo.ebz out of lib/EB/examples/foo.dat.
# Generate lib/EB/res/templates/nl/sampledb.ebz.

schemas :
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=vereniging; \
	cp ../lib/EB/examples/nl/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Vereniging / Stichting" ) | \
	zip -qz ../lib/EB/res/templates/nl/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=bvnv; \
	cp ../lib/EB/examples/nl/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: BV / NV"; \
	  echo "Flags: -btw" ) | \
	zip -qz ../lib/EB/res/templates/nl/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=eenmanszaak; \
	cp ../lib/EB/examples/nl/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Eenmanszaak" ) | \
	zip -qz ../lib/EB/res/templates/nl/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=ondernemer; \
	cp ../lib/EB/examples/nl/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Ondernemer" ) | \
	zip -qz ../lib/EB/res/templates/nl/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=sampledb; \
	cp ../lib/EB/examples/nl/schema.dat .; \
	cp ../lib/EB/examples/nl/relaties.eb .; \
	cp ../lib/EB/examples/nl/mutaties.eb .; \
	cp ../lib/EB/examples/nl/opening.eb .; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: EekBoek voorbeeldadministratie" ) | \
	zip -qz ../lib/EB/res/templates/nl/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \

# Dummies are files that are (re)created by running perl Build.PL.
# However, they are required by the MANIFEST so there should be
# something there already.

dummies :
	echo '---' >META.yml
	echo '' > EekBoek.spec
	echo '' > t/ivp/ref/export.xaf

docs :
	cd ../doc; make all install
