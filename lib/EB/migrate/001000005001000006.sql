-- Migratie EekBoek database van versie 1.0.3 (EB 0.15) naar 1.0.4.

BEGIN WORK;

ALTER TABLE Boekstukken ADD COLUMN bsk_saldo int;

-- Bump version.

UPDATE Constants SET value = 6 WHERE name = 'SCM_REVISION';
UPDATE Metadata  SET adm_scm_revision = 6;

COMMIT WORK;
