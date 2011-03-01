-- Migratie EekBoek database van versie 1.0.0 (EB 0.9) naar 1.0.1 (EB 0.10).

BEGIN WORK;

-- Add new column.

ALTER TABLE Metadata
  ADD COLUMN adm_btwbegin date;
UPDATE Metadata
  SET adm_btwbegin = adm_begin;

-- Bump version.

UPDATE Constants
  SET value = 1
  WHERE name = 'SCM_REVISION';
UPDATE Metadata
  SET adm_scm_revision =
    (SELECT value FROM Constants WHERE name = 'SCM_REVISION');

COMMIT WORK;
