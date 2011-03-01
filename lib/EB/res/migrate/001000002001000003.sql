-- Migratie EekBoek database van versie 1.0.2 (EB 0.14) naar 1.0.3 (EB 0.15).

BEGIN WORK;

-- Change type of bsk_nr to int. Requires a move via a temp column.

-- Add temp column.
ALTER TABLE ONLY Boekstukken ADD COLUMN temp int;
-- Copy current values
UPDATE Boekstukken SET temp = int4(bsk_nr);
-- Delete contraint and old column
ALTER TABLE ONLY Boekstukken DROP CONSTRAINT boekstukken_bsk_nr_key;
ALTER TABLE ONLY Boekstukken DROP COLUMN bsk_nr;
-- Rename temp column
ALTER TABLE ONLY Boekstukken RENAME COLUMN temp TO bsk_nr;
-- Add contraints
ALTER TABLE ONLY Boekstukken ALTER COLUMN bsk_nr SET NOT NULL;
ALTER TABLE ONLY boekstukken
  ADD CONSTRAINT boekstukken_bsk_nr_key UNIQUE (bsk_nr, bsk_dbk_id);

-- Bump version.

UPDATE Constants
  SET value = 3
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
    (SELECT value FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
