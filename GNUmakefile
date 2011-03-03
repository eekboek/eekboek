#! make -f

# This procedure must be executed ONCE after e fresh checkout of
# the development sources.

default :
	@echo "Use the 'bootstrap' target if you know what you are doing." 1>&2
	@test -f META.yml && echo "However, it looks as if this has been done already." 1>&1
	@test -f META.yml && echo "Please double check before proceeding." 1>&1

bootstrap : locales schemas dummies

# Locales. Currently we have parts in english that get translated into
# dutch, and parts in dutch that get translated into english. Someday
# these should be integrated.

MODIR := lib/EB/res/locale
LOCALES := nl en
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
	msgfmt -c -v -o $(MODIR)/nl/LC_MESSAGES/ebwxshell.mo $(PODIR)/ebwxshell-nl.po

# Generate lib/EB/res/templates/foo.ebz out of lib/EB/examples/foo.dat.
# Generate lib/EB/res/templates/sampledb.ebz.

schemas :
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=vereniging; \
	cp ../lib/EB/examples/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Vereniging / Stichting" ) | \
	zip -qz ../lib/EB/res/templates/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=bvnv; \
	cp ../lib/EB/examples/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: BV / NV"; \
	  echo "Flags: -btw" ) | \
	zip -qz ../lib/EB/res/templates/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=eenmanszaak; \
	cp ../lib/EB/examples/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Eenmanszaak" ) | \
	zip -qz ../lib/EB/res/templates/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=ondernemer; \
	cp ../lib/EB/examples/$$name.dat schema.dat; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: Ondernemer" ) | \
	zip -qz ../lib/EB/res/templates/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \
	name=sampledb; \
	cp ../lib/EB/examples/schema.dat .; \
	cp ../lib/EB/examples/relaties.eb .; \
	cp ../lib/EB/examples/mutaties.eb .; \
	cp ../lib/EB/examples/opening.eb .; \
	( echo "Dataset $$name.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: EekBoek voorbeeldadministratie" ) | \
	zip -qz ../lib/EB/res/templates/$$name.ebz *
	rm -fr tmp && mkdir tmp && cd tmp; \

# Dummies are files that are (re)created by running perl Build.PL.
# However, they are required by the MANIFEST so there should be
# something there already.

dummies :
	echo '---' >META.yml
	echo '' > EekBoek.spec
	echo '' > t/ivp/ref/export.xaf
