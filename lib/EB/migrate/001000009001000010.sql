-- Migratie EekBoek database van versie 1.0.9 naar 1.0.10 (EB 1.01.xx).

BEGIN WORK;

-- Table Dagboeken
ALTER TABLE ONLY Dagboeken ADD COLUMN dbk_dcsplit BOOLEAN DEFAULT false;
UPDATE Dagboeken SET dbk_dcsplit = 'false';

-- Table Journal
ALTER TABLE ONLY Journal ADD COLUMN jnl_damount int8;

-- Table Boekstukregels
ALTER TABLE ONLY Boekstukregels DROP COLUMN bsr_id;

-- Table Boekstukken
ALTER TABLE ONLY Boekstukken ADD COLUMN temp int8;
UPDATE Boekstukken SET temp = bsk_id;
ALTER TABLE ONLY Boekstukken DROP COLUMN bsk_id;
ALTER TABLE ONLY Boekstukken RENAME COLUMN temp TO bsk_id;
CREATE SEQUENCE boekstukken_bsk_id_seq;
SELECT setval('boekstukken_bsk_id_seq', max(bsk_id)) FROM Boekstukken;

-- Bump version.

UPDATE Constants
  SET value = 10
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
	(SELECT int4(value) FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
