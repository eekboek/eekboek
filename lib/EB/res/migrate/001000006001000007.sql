-- Migratie EekBoek database van versie 1.0.6 naar 1.0.7 (0.37).

BEGIN WORK;

ALTER TABLE Boekstukregels
  ADD COLUMN bsr_btw_class int;

-- Bump version.

UPDATE Constants SET value = 7 WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
	( SELECT int2(value) FROM Constants WHERE name = 'SCM_REVISION' );

COMMIT WORK;
