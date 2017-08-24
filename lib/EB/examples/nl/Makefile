#! make -f

# Generate lib/EB/res/templates/nl/foo.ebz out of lib/EB/examples/foo.dat.
# Generate lib/EB/res/templates/nl/sampledb.ebz.

default : schemas sampledb

SCHEMAS := bvnv eenmanszaak ondernemer vereniging 
DST := ../../res/templates/nl

################ Schemas ################

schemas : $(foreach s,${SCHEMAS},$s.ebz)

define mkebz
	( echo "Dataset $(1).ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: $(2)"; \
	  if [ -n "$(3)" ]; then echo "$(3)"; fi; \
	) | zip -zqj $(1).ebz $(1).dat
	( echo "@ $(1).dat"; \
	  echo "@=schema.dat"; \
	) | zipnote -w $(1).ebz
endef

vereniging.ebz : vereniging.dat
	$(call mkebz,vereniging,Vereniging / Stichting)

bvnv.ebz : bvnv.dat
	$(call mkebz,bvnv,BV / NV,Flags: -btw)

eenmanszaak.ebz : eenmanszaak.dat
	$(call mkebz,eenmanszaak,Eenmanszaak)

ondernemer.ebz : ondernemer.dat
	$(call mkebz,ondernemer,Ondernemer)

################ Sample DB ################

sampledb : sampledb.ebz

sampledb.ebz : schema.dat relaties.eb mutaties.eb opening.eb
	( echo "Dataset sampledb.ebz aangemaakt door bootstrap"; \
	  echo "Omschrijving: EekBoek voorbeeldadministratie"; \
	) | zip -zqj $@ schema.dat relaties.eb mutaties.eb opening.eb

################ Other ################

define instebz
	rm -f "${DST}/$(1)";
	mv "$(1)" "${DST}/$(1)"
endef

install : schemas sampledb
	$(foreach s,${SCHEMAS} sampledb,$(call instebz,$s.ebz);)

clean :
	$(foreach s,${SCHEMAS} sampledb,rm -f $s.ebz;)


