-- EekBoek Database Schema
-- $Id: eekboek.sql,v 1.11 2005/08/15 19:52:31 jv Exp $

\i constants.sql

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
    acc_btw     smallint,
    acc_ibalance int,     -- openingsbalanswaarde
    acc_balance int
);

\i acc.sql

CREATE TABLE Standaardrekeningen (
  std_acc_deb	   int references Accounts,	-- debiteurenrekening
  std_acc_crd	   int references Accounts,	-- crediteurenrekening
  std_acc_btw_ih   int references Accounts,	-- BTW inkoop hoog
  std_acc_btw_il   int references Accounts,	-- BTW inkoop laag
  std_acc_btw_vh   int references Accounts,	-- BTW verkoop hoog
  std_acc_btw_vl   int references Accounts,	-- BTW verkoop laag
  std_acc_btw_ok   int references Accounts,	-- BTW betaald
  std_acc_winst    int references Accounts	-- Winstrekening
);

\i std.sql

-- Standaardrekeningen mogen niet meer worden gewijzigd als de
-- administratie eenmaal is geopend.

CREATE FUNCTION check_opened()
  RETURNS trigger
  AS 'DECLARE
	ret DATE;
      BEGIN
	SELECT INTO ret 
		adm_opened
		FROM Metadata
		WHERE adm_opened IS NULL;
	IF NOT FOUND
	THEN
	  RAISE EXCEPTION ''Administratie is reeds geopend'';
	END IF;
	RETURN new;
      END;
  ' LANGUAGE 'plpgsql';

CREATE TRIGGER std_change
  BEFORE INSERT OR UPDATE
  ON Standaardrekeningen
  EXECUTE PROCEDURE check_opened();

-- BTW Tariefgroepen
CREATE TABLE BTWTariefgroepen (
  btg_id          smallint not null primary key,
  btg_desc        text not null,
  btg_acc_inkoop  int references Accounts,
  btg_acc_verkoop int references Accounts
);

-- BTW tarieven
CREATE TABLE BTWTabel (
  btw_id          smallint not null primary key,
  btw_desc        text not null,
  btw_perc        int not null,      -- perc * BTWSCALE
  btw_tariefgroep smallint not null references BTWTariefgroepen,
  btw_incl        boolean    -- inclusief / exclusief
);

\i btw.sql

ALTER TABLE ONLY Accounts
    add constraint "acc_btw_fk_btw_id"
        FOREIGN KEY (acc_btw) REFERENCES BTWTabel(btw_id);

CREATE TABLE Dagboeken (

  dbk_id        int not null primary key,
  dbk_desc      text not null,
  dbk_type      smallint not null, -- inkoop, verkoop, bank/giro, kas, memoriaal
  dbk_acc_id    int references Accounts
);

\i dbk.sql

CREATE SEQUENCE bsk_nr_0_seq;

-- Debiteuren / Crediteuren

-- Note that rel_debcrd is for convenience only, since it always
-- matches acc_debcrd of rec_acc_id.

CREATE TABLE Relaties (
  rel_code      char(10) not null primary key,
  rel_desc 	text not null,
  rel_debcrd 	boolean,	-- t: debiteur f: crediteur
  rel_btw_status smallint default 0, -- BTW_NORMAAL, BTW_VERLEGD, BTW_INTRA, BTW_EXTRA.
  rel_ledger    int references Dagboeken,  -- verkoop/inkoopdagboek
  rel_acc_id    int references Accounts	   -- standaard grootboekrekening
);

CREATE TABLE Boekstukken (

  bsk_id       serial not null primary key,
  bsk_nr       char(4),	-- free choice
  bsk_desc     text not null,
  bsk_dbk_id   int references Dagboeken,
  bsk_date     date,
  bsk_amount   int,
  bsk_paid     int,
  UNIQUE(bsk_nr, bsk_dbk_id)
);

CREATE TABLE Boekstukregels (

  bsr_id       serial not null primary key,
  bsr_nr       int,	-- 1, 2, 3, ...
  bsr_date     date,
  bsr_bsk_id   int references Boekstukken,
  bsr_desc     text, -- editable copy van bsk_desc
  bsr_amount   int,
  bsr_btw_id   smallint references BTWTabel,
  bsr_btw_acc  int references Accounts,
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
  bsr_rel_code  CHAR(10) references Relaties,
                -- BKM: Debiteur (betaling van), Crediteur (betaling aan)
                -- I: Crediteur, V: Debiteur
  UNIQUE(bsr_nr, bsr_bsk_id)
);

ALTER TABLE ONLY Boekstukken
    add constraint "bsk_paid_fk_bsr_id"
        FOREIGN KEY (bsk_paid) REFERENCES Boekstukregels(bsr_id);

CREATE TABLE Journal (
  jnl_date	date not null,
  jnl_dbk_id	int references Dagboeken,
  jnl_bsk_id	int not null references Boekstukken,
  jnl_bsr_seq	int not null,
  jnl_acc_id	int references Accounts,
  jnl_amount	int,
  jnl_desc	text,
  jnl_rel	CHAR(10) references Relaties,
  UNIQUE(jnl_bsk_id, jnl_dbk_id, jnl_bsr_seq)
);

CREATE TABLE Metadata (
  adm_scm_majversion smallint NOT NULL,
  adm_scm_minversion smallint NOT NULL,
  adm_scm_revision   smallint NOT NULL,
  adm_name	text,
  adm_begin	date,
    -- btw periode: 0 = geen, 1 = jaar, 4 = kwartaal
  adm_btwperiod	smallint,
  adm_opened	date,
  adm_closed	date
);

INSERT INTO metadata (adm_scm_majversion, adm_scm_minversion, adm_scm_revision, adm_begin)
  values((select value from constants where name = 'SCM_MAJVERSION'),
	 (select value from constants where name = 'SCM_MINVERSION'),
	 (select value from constants where name = 'SCM_REVISION'),
	 date_trunc('year',now())
	);
