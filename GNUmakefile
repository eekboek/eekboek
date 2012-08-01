#! make -f

# This procedure must be executed ONCE after e fresh checkout of
# the development sources.

default :
	@echo "Use the 'bootstrap' target if you know what you are doing." 1>&2
	@test -f META.yml && echo "However, it looks as if this has been done already." 1>&1
	@test -f META.yml && echo "Please double check before proceeding." 1>&1

MAKEFLAGS += -j1		# all serial

bootstrap : locales schemas dummies

# Locales. Currently we have parts in english that get translated into
# dutch, and parts in dutch that get translated into english. Someday
# these should be integrated.

MODIR := lib/EB/res/locale
LOCALES := en
xxlocales :
	for locale in $(LOCALES); \
	do \
	  test -d $(MODIR)/$$locale || mkdir -p $(MODIR)/$$locale; \
	  ( cd locale; \
	    sh make_locales_$$locale; \
	  ); \
	done

PODIR := locale
locales :
	for locale in $(LOCALES); \
	do \
	  test -d $(MODIR)/$$locale/LC_MESSAGES || mkdir -p $(MODIR)/$$locale/LC_MESSAGES; \
	done
	msgfmt -c -v -o $(MODIR)/en/LC_MESSAGES/ebcore.mo    $(PODIR)/ebcore-en.po

# Generate lib/EB/res/templates/nl/foo.ebz out of lib/EB/examples/foo.dat.
# Generate lib/EB/res/templates/nl/sampledb.ebz.

schemas : schemas_nl schemas_en

schemas_nl :
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

schemas_en :
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=sampledb; \
	cp ../lib/EB/examples/en/schema.dat .; \
	cp ../lib/EB/examples/en/relaties.eb .; \
	cp ../lib/EB/examples/en/mutaties.eb .; \
	cp ../lib/EB/examples/en/opening.eb .; \
	( echo "Dataset $$name.ebz created by bootstrap"; \
	  echo "Description: EekBoek Sample Administration" ) | \
	zip -qz ../lib/EB/res/templates/en/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \

# Dummies are files that are (re)created by running perl Build.PL.
# However, they are required by the MANIFEST so there should be
# something there already.

dummies :
	echo '---' >META.yml
	echo '' > EekBoek.spec
	echo '' > t/ivp/ref/export.xaf
	unzip -q -o doc/docs.zip
