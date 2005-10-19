-- Migratie EekBoek database van versie 1.0.3 (EB 0.15) naar 1.0.4.

BEGIN WORK;

-- Constants: value int -> text
ALTER TABLE Constants ADD COLUMN newval text;
UPDATE Constants SET newval = text(value);
ALTER TABLE Constants DROP COLUMN value;
ALTER TABLE Constants RENAME COLUMN newval TO value;
INSERT INTO Constants (name,value) VALUES ('BKY_PREVIOUS','<<<<');

DELETE FROM Constants WHERE name = 'BTWPER_HALFJAAR';
DELETE FROM Constants WHERE name = 'BTWPER_TRIMESTER';
INSERT INTO Constants (name,value) VALUES ('BTWPER_MAAND','12');

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
    (bky_code, bky_name, bky_begin, bky_end, bky_btwperiod, bky_opened, bky_closed)
    VALUES('<<<<', 'Voorgaand boekjaar', '1900-01-01',
	   (SELECT adm_begin - INTERVAL '1 day' FROM Metadata),
           0, (SELECT now()), (SELECT now()));
INSERT INTO Boekjaren
    (bky_code, bky_name, bky_begin, bky_end, bky_btwperiod, bky_opened, bky_closed)
    VALUES((SELECT EXTRACT(YEAR FROM adm_begin) FROM Metadata),
	   (SELECT adm_name FROM Metadata),
	   (SELECT adm_begin FROM Metadata),
	   (SELECT adm_begin + INTERVAL '1 year' - INTERVAL '1 day' FROM Metadata),
	   (SELECT adm_btwperiod FROM Metadata),
	   (SELECT adm_closed FROM Metadata),
	   (SELECT adm_opened FROM Metadata));

ALTER TABLE Metadata ADD COLUMN adm_bky VARCHAR(4) REFERENCES Boekjaren;
UPDATE Metadata
  SET adm_bky = (SELECT EXTRACT(YEAR FROM adm_begin) FROM Metadata);

ALTER TABLE Boekstukken
  ADD COLUMN bsk_bky varchar(4) REFERENCES Boekjaren;
UPDATE Boekstukken
  SET bsk_bky = EXTRACT(YEAR FROM bsk_date)
    WHERE bsk_date >= (SELECT adm_begin FROM Metadata);
UPDATE Boekstukken
  SET bsk_bky = '<<<<'
    WHERE bsk_bky IS NULL;

ALTER TABLE ONLY boekstukken
    DROP CONSTRAINT boekstukken_bsk_nr_key;
ALTER TABLE ONLY boekstukken
    ADD CONSTRAINT boekstukken_bsk_nr_key UNIQUE (bsk_nr, bsk_dbk_id, bsk_bky);

CREATE TABLE Boekjaarbalans (
    bkb_bky      varchar(4) references Boekjaren,
    bkb_end	 date,
    bkb_acc_id   int references Accounts,
    bkb_balance  int
);

ALTER TABLE Metadata DROP COLUMN adm_name;
ALTER TABLE Metadata DROP COLUMN adm_begin;
ALTER TABLE Metadata DROP COLUMN adm_btwperiod;
ALTER TABLE Metadata DROP COLUMN adm_opened;
ALTER TABLE Metadata DROP COLUMN adm_closed;

-- Bump version.

UPDATE Constants SET value = 4 WHERE name = 'SCM_REVISION';
UPDATE Metadata  SET adm_scm_revision = 4;

COMMIT WORK;
