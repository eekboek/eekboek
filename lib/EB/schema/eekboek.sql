-- EekBoek Database Schema
-- $Id: eekboek.sql,v 1.35 2008/03/10 17:42:04 jv Exp $

-- Constanten. Deze worden gegenereerd door de EB::Globals module.
CREATE TABLE Constants (
    name	text not null primary key,
    value	text
);

\i constants.sql

-- Verdichtingen
CREATE TABLE Verdichtingen (
    vdi_id     int not null primary key,
    vdi_desc   text not null,
    vdi_balres boolean,       -- t:balans f:resultaten
    vdi_kstomz boolean,       -- t:kosten f:omzet
    vdi_struct int references Verdichtingen
);

\i vrd.sql

-- Grootboekrekeningen
CREATE TABLE Accounts (
    acc_id      int not null primary key,
    acc_desc    text not null,
    acc_struct  int references Verdichtingen,
    acc_balres  boolean,       -- t:balans f:resultaten
    acc_debcrd  boolean,       -- t:debet  f:credit
    acc_kstomz  boolean,       -- t:kosten f:omzet
    acc_btw     smallint,      -- references BTWTabel (constraint postponed)
    acc_ibalance int8,          -- openingsbalanswaarde
    acc_balance int8
);

\i acc.sql

CREATE TABLE Standaardrekeningen (
    std_acc_deb	     int references Accounts,	-- debiteurenrekening
    std_acc_crd	     int references Accounts,	-- crediteurenrekening
    std_acc_btw_ih   int references Accounts,	-- BTW inkoop hoog
    std_acc_btw_il   int references Accounts,	-- BTW inkoop laag
    std_acc_btw_vh   int references Accounts,	-- BTW verkoop hoog
    std_acc_btw_vl   int references Accounts,	-- BTW verkoop laag
    std_acc_btw_vp   int references Accounts,	-- BTW verkoop privé
    std_acc_btw_ip   int references Accounts,	-- BTW inkoop privé
    std_acc_btw_va   int references Accounts,	-- BTW verkoop anders
    std_acc_btw_ia   int references Accounts,	-- BTW inkoop anders
    std_acc_btw_ok   int references Accounts,	-- BTW betaald
    std_acc_winst    int references Accounts	-- Winstrekening
);

\i std.sql

-- BTW tarieven
CREATE TABLE BTWTabel (
    btw_id          smallint not null primary key,
    btw_desc        text not null,
    btw_perc        int not null,      -- perc * BTWSCALE
    btw_tariefgroep smallint not null, -- 0 (Geen) 1 (Hoog) 2 (Laag)
    btw_incl        boolean,           -- inclusief / exclusief
    CONSTRAINT "btw_tariefgroep"
	CHECK (btw_tariefgroep >= 0 AND btw_tariefgroep <= 4)
);

\i btw.sql

ALTER TABLE ONLY Accounts
    add constraint "acc_btw_fk_btw_id"
        FOREIGN KEY (acc_btw) REFERENCES BTWTabel(btw_id);

-- Dagboeken
CREATE TABLE Dagboeken (
    dbk_id        varchar(4) primary key,
    dbk_desc      text not null,
    dbk_type      smallint not null, -- inkoop, verkoop, bank/giro, kas, memoriaal
    dbk_dcsplit	  boolean default false, -- splits journaal bedrag in debet/credit
    dbk_acc_id    int references Accounts,
    CONSTRAINT "dbk_types"
	CHECK (dbk_type >= 1 AND dbk_type <= 5)
);

\i dbk.sql

-- Sequence voor openstaande / vorig boekjaar boekingen.
CREATE SEQUENCE bsk_nr_0_seq;

-- Debiteuren / Crediteuren

-- Note that rel_debcrd is for convenience only, since it always
-- matches acc_debcrd of rec_acc_id.

CREATE TABLE Relaties (
    rel_code      char(10) not null,
    rel_desc 	  text not null,
    rel_debcrd    boolean,		     -- t: debiteur f: crediteur
    rel_btw_status smallint default 0, 	     -- BTWTYPE NORMAAL, VERLEGD, INTRA, EXTRA.
    rel_ledger    varchar(4) references Dagboeken,  -- verkoop/inkoopdagboek
    rel_acc_id    int references Accounts,   -- standaard grootboekrekening
    CONSTRAINT "relaties_pkey"
        PRIMARY KEY (rel_code, rel_ledger),
    CONSTRAINT "rel_btw_status"
	CHECK (rel_btw_status >= 0 AND rel_btw_status <= 3)
);

-- Boekjaren
CREATE TABLE Boekjaren (
    bky_code	 varchar(4) not null primary key,
    bky_name	 text not null,
    bky_begin	 date not null,
    bky_end	 date not null,
      -- btw periode: 0 = geen, 1 = jaar, 4 = kwartaal, 12 = maand
    bky_btwperiod smallint,
    bky_opened	  date,	-- openingsdatum
    bky_closed	  date,	-- sluitdatum
    CONSTRAINT "bky_btwperiod"
	CHECK (bky_btwperiod = 0 OR bky_btwperiod = 1 OR bky_btwperiod = 4 OR bky_btwperiod = 12)
);

-- Verplichte entry voor openstaande boekingen (openingsbalans).
INSERT INTO Boekjaren
    (bky_code, bky_name, bky_begin, bky_end, bky_btwperiod, bky_opened)
    VALUES('<<<<', 'Voorgaand boekjaar', '1900-01-01', '2099-12-31', 0, (SELECT now()));

-- Boekstukken
CREATE TABLE Boekstukken (
    bsk_id       int not null primary key,
    bsk_nr       int not null,	-- serienummer
    bsk_desc     text not null,
    bsk_ref	 text,		-- referentie
    bsk_dbk_id   varchar(4) references Dagboeken,
    bsk_date     date,
    bsk_bky      VARCHAR(4) references Boekjaren,
    bsk_amount   int8,		-- bedrag, negatief voor inkoop
    bsk_open     int8,		-- openstaand bedrag
    bsk_isaldo	 int8,		-- beginsaldo boeking
    bsk_saldo	 int8,		-- eindsaldo na boeking
    UNIQUE(bsk_nr, bsk_dbk_id, bsk_bky)
);

-- Sequence voor Boekstuknummers
CREATE SEQUENCE boekstukken_bsk_id_seq;

-- Boekstukregels
CREATE TABLE Boekstukregels (
    bsr_nr       int,	-- volgnummer in dit boekstuk (1, 2, 3, ...)
    bsr_date     date,
    bsr_bsk_id   int references Boekstukken,
    bsr_desc     text, -- editable copy van bsk_desc
    bsr_amount   int8,
    bsr_btw_id   smallint references BTWTabel,
    bsr_btw_acc  int references Accounts,
    bsr_btw_class  int, -- see BTWKLASSE definities
--
    bsr_type      smallint,
                  -- I: Standaard, [- Artikel (levering van) -], ...,
                  --    Open post vorige periode
                  -- BKM: Standaard, Debiteur (betaling), Crediteur (betaling)
                  -- V: -, ...,
                  --    Open post vorige periode
    bsr_acc_id    int references Accounts,
                  -- IBKM: Standaard
                  -- V
--  #bsr_art_id   I: Artikel (levering van)
--  #bsr_art_num  I: Artikel (levering van)
    bsr_rel_code  CHAR(10),
                  -- BKM: Debiteur (betaling van), Crediteur (betaling aan)
                  -- I: Crediteur, V: Debiteur (alle bsrs dezelfde)
    bsr_dbk_id    VARCHAR(4) references Dagboeken,
    bsr_paid	  int references Boekstukken,
		  -- Boekstuknummer dat door deze bsr wordt betaald
    UNIQUE(bsr_nr, bsr_bsk_id),
    CONSTRAINT "bsr_fk_rel"
	FOREIGN KEY (bsr_rel_code, bsr_dbk_id) REFERENCES Relaties,
    CONSTRAINT "bsr_type"
	CHECK (bsr_type >= 0 AND bsr_type <= 2 OR bsr_type = 9)
);

-- Journal
CREATE TABLE Journal (
    jnl_date	date not null,	--boekstukdatum
    jnl_dbk_id	varchar(4) references Dagboeken,
    jnl_bsk_id	int not null references Boekstukken,
    jnl_bsk_ref text,
    jnl_bsr_date date not null,	--boekstukregeldatum
    jnl_bsr_seq	int not null,
    jnl_acc_id	int references Accounts,
    jnl_amount	int8,	-- total amount
    jnl_damount	int8,	-- debet portion
    jnl_desc	text,
    jnl_rel	CHAR(10),
    jnl_rel_dbk	varchar(4) references Dagboeken,
    CONSTRAINT "jnl_fk_rel"
	FOREIGN KEY (jnl_rel, jnl_rel_dbk) REFERENCES Relaties,
    UNIQUE(jnl_bsk_id, jnl_dbk_id, jnl_bsr_seq)
);

CREATE TABLE Boekjaarbalans (
    bkb_bky      varchar(4) references Boekjaren,
    bkb_end	 date,
    bkb_acc_id   int references Accounts,
    bkb_balance  int8
);

-- Metadata
CREATE TABLE Metadata (
    adm_scm_majversion  smallint NOT NULL,
    adm_scm_minversion  smallint NOT NULL,
    adm_scm_revision    smallint NOT NULL,
    adm_bky		varchar(4) references Boekjaren,
    adm_btwbegin	date	-- begin huidige BTW periode
);

-- Harde waarden, moeten overeenkomen met de code.
INSERT INTO metadata (adm_scm_majversion, adm_scm_minversion, adm_scm_revision)
  VALUES (1, 0, 13);

UPDATE Metadata SET adm_bky = '<<<<'; -- Voorgaand boekjaar
